library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_seven_seg_scroll_bcd is
end entity;

architecture sim of tb_seven_seg_scroll_bcd is

    constant SIM_FREQ   : integer := 100_000;       -- scaled-down "clock frequency"
    constant CLK_PERIOD : time    := 10 ns;
    constant STEP_CYC   : integer := SIM_FREQ/2;    -- clock cycles per scroll step

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal start   : std_logic := '0';
    signal bcd_out : std_logic_vector(3 downto 0);
    signal sel_out : std_logic_vector(3 downto 0);

    type win_t is array (0 to 3) of std_logic_vector(3 downto 0);
    signal window : win_t := (others => "1111");    -- window(0)=S1 (right) ... window(3)=S4 (left)

    -- Expected code at digit idx for a given scroll step (Table 5)
    function expected(step, idx : integer) return std_logic_vector is
        variable pos : integer := step - idx;
    begin
        if pos >= 1 and pos <= 9 then
            return std_logic_vector(to_unsigned(pos, 4));
        elsif pos = 10 then
            return "0000";
        else
            return "1111";
        end if;
    end function;

begin

    uut : entity work.seven_seg_scroll_bcd
        generic map (CLK_FREQ => SIM_FREQ)
        port map (clk => clk, reset => reset, start => start,
                  bcd_out => bcd_out, sel_out => sel_out);

    clk <= not clk after CLK_PERIOD/2;

    -- Capture the BCD bus value for whichever digit is enabled,
    -- and flag ghosting (more than one digit enabled at once).
    -- If SEL_ACTIVE is '0' in the design, change '1' to '0' here.
    capture : process(clk)
        variable ones : integer;
    begin
        if rising_edge(clk) then
            ones := 0;
            for i in 0 to 3 loop
                if sel_out(i) = '1' then
                    ones := ones + 1;
                end if;
            end loop;
            assert ones <= 1
                report "GHOSTING: more than one digit enabled" severity error;
            for i in 0 to 3 loop
                if sel_out(i) = '1' then
                    window(i) <= bcd_out;
                end if;
            end loop;
        end if;
    end process;

    -- Stimulus and checker
    stim : process
        variable errors : integer := 0;

        procedure check(step : integer) is
        begin
            for i in 0 to 3 loop
                if window(i) /= expected(step, i) then
                    report "Step " & integer'image(step) & ": digit S" &
                           integer'image(i+1) & " mismatch" severity error;
                    errors := errors + 1;
                end if;
            end loop;
            report "Step " & integer'image(step) & " checked: S4..S1 = " &
                   integer'image(to_integer(unsigned(window(3)))) & " " &
                   integer'image(to_integer(unsigned(window(2)))) & " " &
                   integer'image(to_integer(unsigned(window(1)))) & " " &
                   integer'image(to_integer(unsigned(window(0)))) &
                   "  (15 = blank)" severity note;
        end procedure;
    begin
        reset <= '1';
        wait for 10 * CLK_PERIOD;
        reset <= '0';
        wait for 4000 * CLK_PERIOD;              -- let IDLE settle
        check(0);                                -- idle: all blank

        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        wait for (STEP_CYC / 2) * CLK_PERIOD;    -- middle of step 1
        check(1);
        for k in 2 to 14 loop
            wait for STEP_CYC * CLK_PERIOD;
            check(k);
        end loop;

        wait for STEP_CYC * CLK_PERIOD;          -- loop restarts automatically
        check(1);

        -- Reset in the middle of a run must return to all blank
        reset <= '1';
        wait for 4000 * CLK_PERIOD;
        reset <= '0';
        wait for 4000 * CLK_PERIOD;
        check(0);

        if errors = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture;
