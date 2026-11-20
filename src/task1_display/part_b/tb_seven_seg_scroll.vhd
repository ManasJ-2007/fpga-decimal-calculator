library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_seven_seg_scroll is
end entity;

architecture sim of tb_seven_seg_scroll is

    constant SIM_FREQ   : integer   := 100_000;     -- scaled-down "clock frequency"
    constant CLK_PERIOD : time      := 10 ns;
    constant STEP_CYC   : integer   := SIM_FREQ/2;  -- clock cycles per scroll step

    -- Must match the generics used by the design
    constant SEL_ACT : std_logic := '1';
    constant SEG_LOW : boolean   := true;

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal start   : std_logic := '0';
    signal seg_out : std_logic_vector(6 downto 0);
    signal dp_out  : std_logic;
    signal sel_out : std_logic_vector(3 downto 0);

    -- Independent copy of the segment table (a b c d e f g, active high)
    type seg_tbl_t is array (0 to 10) of std_logic_vector(6 downto 0);
    constant TBL : seg_tbl_t := (
        "1111110", "0110000", "1101101", "1111001", "0110011",
        "1011011", "1011111", "1110000", "1111111", "1111011",
        "0000001");                                  -- index 10 = minus

    -- Expected stream (10 = minus): 3922 - 3923. Keep in sync with the design.
    type int_arr_t is array (1 to 9) of integer;
    constant STREAM : int_arr_t := (3, 9, 2, 2, 10, 3, 9, 2, 3);

    type win_t is array (0 to 3) of std_logic_vector(6 downto 0);
    signal window : win_t := (others => "0000000");  -- window(0)=S1 (right) ... window(3)=S4 (left)

    function expected(step, idx : integer) return std_logic_vector is
        variable pos : integer := step - idx;
    begin
        if pos >= 1 and pos <= 9 then
            return TBL(STREAM(pos));
        else
            return "0000000";
        end if;
    end function;

    function sym(s : std_logic_vector(6 downto 0)) return character is
    begin
        for i in 0 to 9 loop
            if s = TBL(i) then
                return character'val(48 + i);
            end if;
        end loop;
        if s = TBL(10)  then return '-'; end if;
        if s = "0000000" then return '_'; end if;
        return '?';
    end function;

begin

    uut : entity work.seven_seg_scroll
        generic map (CLK_FREQ => SIM_FREQ, SEL_ACTIVE => SEL_ACT, SEG_ACTIVE_LOW => SEG_LOW)
        port map (clk => clk, reset => reset, start => start,
                  seg_out => seg_out, dp_out => dp_out, sel_out => sel_out);

    clk <= not clk after CLK_PERIOD/2;

    -- Record the (active-high) segments of whichever digit is enabled,
    -- and flag ghosting (more than one digit enabled at once).
    capture : process(clk)
        variable ones : integer;
    begin
        if rising_edge(clk) then
            ones := 0;
            for i in 0 to 3 loop
                if sel_out(i) = SEL_ACT then
                    ones := ones + 1;
                    if SEG_LOW then
                        window(i) <= not seg_out;
                    else
                        window(i) <= seg_out;
                    end if;
                end if;
            end loop;
            assert ones <= 1
                report "GHOSTING: more than one digit enabled" severity error;
        end if;
    end process;

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
            report "Step " & integer'image(step) & " checked: S4..S1 = [" &
                   sym(window(3)) & sym(window(2)) & sym(window(1)) & sym(window(0)) &
                   "]  (_ = blank)" severity note;
        end procedure;
    begin
        reset <= '1';
        wait for 10 * CLK_PERIOD;
        reset <= '0';
        wait for 4000 * CLK_PERIOD;
        check(0);                                -- idle: all blank

        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        wait for (STEP_CYC / 2) * CLK_PERIOD;    -- middle of step 1
        check(1);
        for k in 2 to 13 loop                    -- step 13 = full blank phase
            wait for STEP_CYC * CLK_PERIOD;
            check(k);
        end loop;

        wait for STEP_CYC * CLK_PERIOD;          -- loop restarts automatically
        check(1);

        reset <= '1';                            -- reset mid-run -> all blank
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
