library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seven_seg_scroll_bcd is
    generic (CLK_FREQ : integer := 50_000_000);   -- set to your board oscillator
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        start    : in  std_logic;
        bcd_out  : out std_logic_vector(3 downto 0);  -- J1 pins A,B,C,D (LSB = A)
        sel_out  : out std_logic_vector(3 downto 0)   -- J1 pins D1..D4
    );
end entity;

architecture rtl of seven_seg_scroll_bcd is

    -- Change to '0' if the board's digit selects are active-low
    constant SEL_ACTIVE : std_logic := '1';

    -- 74LS47 blanks the digit for input 1111
    constant BLANK : std_logic_vector(3 downto 0) := "1111";

    -- Scroll controller FSM
    type state_t is (IDLE, SCROLL, BLANK_PHASE);
    signal state : state_t := IDLE;
    signal step  : integer range 0 to 14 := 0;

    signal tick_mux    : std_logic;
    signal tick_scroll : std_logic;

    -- Multiplexer
    signal dig_idx : integer range 0 to 3 := 0;
    signal gap     : std_logic := '1';

    type digits_t is array (0 to 3) of std_logic_vector(3 downto 0);
    signal digits : digits_t;   -- digits(0)=S1 (right) ... digits(3)=S4 (left)

    -- Stream "1 2 3 4 5 6 7 8 9 0": position 1..10, anything else = blank
    function stream_digit(pos : integer) return std_logic_vector is
    begin
        if pos >= 1 and pos <= 9 then
            return std_logic_vector(to_unsigned(pos, 4));
        elsif pos = 10 then
            return "0000";
        else
            return BLANK;
        end if;
    end function;

begin

    -- 1 kHz and 2 Hz tick generator
    u_div : entity work.clk_divider
        generic map (CLK_FREQ => CLK_FREQ)
        port map (clk => clk, reset => reset,
                  tick_mux => tick_mux, tick_scroll => tick_scroll);

    ---------------------------------------------------------------
    -- Scroll FSM: IDLE -> SCROLL (steps 1..13) -> BLANK_PHASE (step 14)
    --             -> SCROLL (step 1) ...
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                step  <= 0;
            else
                case state is

                    when IDLE =>
                        step <= 0;
                        if start = '1' then
                            state <= SCROLL;
                            step  <= 1;
                        end if;

                    when SCROLL =>
                        if tick_scroll = '1' then
                            if step = 13 then
                                state <= BLANK_PHASE;
                                step  <= 14;
                            else
                                step <= step + 1;
                            end if;
                        end if;

                    when BLANK_PHASE =>
                        if tick_scroll = '1' then
                            state <= SCROLL;
                            step  <= 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- 4-digit window over the stream (Table 5)
    digits(0) <= stream_digit(step);       -- S1 (right)
    digits(1) <= stream_digit(step - 1);   -- S2
    digits(2) <= stream_digit(step - 2);   -- S3
    digits(3) <= stream_digit(step - 3);   -- S4 (left)

    ---------------------------------------------------------------
    -- Multiplexer: on each 1 kHz tick all digits are switched off and the
    -- BCD data changes; one clock later the new digit is enabled.
    -- Exactly one digit is on at a time, so there is no ghosting.
    ---------------------------------------------------------------
    process(clk)
        variable nxt : integer range 0 to 3;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                dig_idx <= 0;
                gap     <= '1';
                sel_out <= (others => not SEL_ACTIVE);
                bcd_out <= BLANK;
            elsif tick_mux = '1' then
                if dig_idx = 3 then
                    nxt := 0;
                else
                    nxt := dig_idx + 1;
                end if;
                dig_idx <= nxt;
                sel_out <= (others => not SEL_ACTIVE);
               bcd_out <= digits(3 - nxt);
                gap     <= '1';
            elsif gap = '1' then
                sel_out          <= (others => not SEL_ACTIVE);
                sel_out(dig_idx) <= SEL_ACTIVE;   -- D1 = S1 ... D4 = S4
                gap              <= '0';
            end if;
        end if;
    end process;

end architecture;
