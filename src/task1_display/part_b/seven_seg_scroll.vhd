library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seven_seg_scroll is
    generic (
        CLK_FREQ        : integer   := 50_000_000;  -- Xen10 on-board 50 MHz clock
        SEL_ACTIVE      : std_logic := '1';         -- level that enables a digit (use the value that worked in Part A)
        SEG_ACTIVE_LOW  : boolean   := true         -- common-anode display: a segment lights when its line is LOW
    );
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        start   : in  std_logic;
        seg_out : out std_logic_vector(6 downto 0);  -- Connects directly to segments a-g
        dp_out  : out std_logic;
        sel_out : out std_logic_vector(3 downto 0)   -- Connects to hardware S1-S4
    );
end entity;

architecture behavioral of seven_seg_scroll is

    signal mux_clk    : std_logic := '0';   -- 1 kHz refresh tick (one-clock pulse)
    signal scroll_clk : std_logic := '0';   -- 2 Hz scroll tick   (one-clock pulse)

    -- Internal display buffer storing 4-bit encoded values (window shown on S1..S4)
    type display_buffer_t is array (0 to 3) of std_logic_vector(3 downto 0);
    signal current_digits : display_buffer_t;

    ---------------------------------------------------------------
    -- Scroll stream: Display_Buffer[8] is the first symbol, [0] the last.
    -- EDIT the two groups of four digits below:
    --   first group  = last 4 digits of roll no. of teammate 1 (3922)
    --   second group = last 4 digits of roll no. of teammate 2 (3923)
    ---------------------------------------------------------------
    type stream_t is array (0 to 8) of std_logic_vector(3 downto 0);

    function d(n : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(n, 4));
    end function;

    constant MINUS      : std_logic_vector(3 downto 0) := "1010";
    constant BLANK_CODE : std_logic_vector(3 downto 0) := "1111";

    constant DISPLAY_BUFFER : stream_t := (
        8 => d(3), 7 => d(9), 6 => d(2), 5 => d(2),    -- first number  (3922)
        4 => MINUS,                                    -- minus sign
        3 => d(3), 2 => d(9), 1 => d(2), 0 => d(3)     -- second number (3923)
    );

    constant N_SYM      : integer := 9;
    constant LAST_STEP  : integer := N_SYM + 3;        -- last digit leaves S4 (step 12)
    constant BLANK_STEP : integer := N_SYM + 4;        -- full-blank phase (step 13)

    -- Symbol shown on digit k (0 = S1 right ... 3 = S4 left) at scroll step s
    function window_code(s, k : integer) return std_logic_vector is
        variable pos : integer;
    begin
        pos := s - k;
        if pos >= 1 and pos <= N_SYM then
            return DISPLAY_BUFFER(N_SYM - pos);
        else
            return BLANK_CODE;
        end if;
    end function;

    function seg_off_value return std_logic_vector is
    begin
        if SEG_ACTIVE_LOW then
            return "1111111";
        else
            return "0000000";
        end if;
    end function;

    constant SEG_OFF : std_logic_vector(6 downto 0) := seg_off_value;

    -- Clock dividers
    constant MUX_MAX    : integer := CLK_FREQ/1000 - 1;
    constant SCROLL_MAX : integer := CLK_FREQ/2 - 1;
    signal mux_cnt    : integer range 0 to MUX_MAX    := 0;
    signal scroll_cnt : integer range 0 to SCROLL_MAX := 0;

    -- Scroll FSM
    type state_t is (IDLE, SCROLL, BLANK_PHASE);
    signal state : state_t := IDLE;
    signal step  : integer range 0 to BLANK_STEP := 0;

    -- Multiplexer
    signal dig_idx  : integer range 0 to 3 := 0;
    signal phase    : integer range 0 to 2 := 2;
    signal code_sel : std_logic_vector(3 downto 0);
    signal seg_dec  : std_logic_vector(6 downto 0);
    signal seg_phys : std_logic_vector(6 downto 0);

begin

    ---------------------------------------------------------------
    -- Clock dividers (produce one-clock-cycle ticks from the 50 MHz clock).
    -- The scroll counter is held at 0 while IDLE so that every scroll
    -- step, including the first, lasts exactly 0.5 s.
    ---------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            mux_clk    <= '0';
            scroll_clk <= '0';
            if reset = '1' then
                mux_cnt    <= 0;
                scroll_cnt <= 0;
            else
                if mux_cnt = MUX_MAX then
                    mux_cnt <= 0;
                    mux_clk <= '1';
                else
                    mux_cnt <= mux_cnt + 1;
                end if;

                if state = IDLE then
                    scroll_cnt <= 0;
                elsif scroll_cnt = SCROLL_MAX then
                    scroll_cnt <= 0;
                    scroll_clk <= '1';
                else
                    scroll_cnt <= scroll_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- Display FSM: IDLE -> SCROLL (steps 1..12) -> BLANK_PHASE (step 13)
    --              -> SCROLL (step 1) ...
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
                        if scroll_clk = '1' then
                            if step = LAST_STEP then
                                state <= BLANK_PHASE;
                                step  <= BLANK_STEP;
                            else
                                step <= step + 1;
                            end if;
                        end if;

                    when BLANK_PHASE =>
                        if scroll_clk = '1' then
                            state <= SCROLL;
                            step  <= 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- Window shown on the display (Table 8)
    gen_window : for k in 0 to 3 generate
        current_digits(k) <= window_code(step, k);
    end generate;

    ---------------------------------------------------------------
    -- Own decoder: code of the currently selected digit -> segments
    ---------------------------------------------------------------
    code_sel <= current_digits(3 - dig_idx);

    u_dec : entity work.seven_seg_decoder
        port map (code_in => code_sel, seg_out => seg_dec);

    -- Decoder is active-high; invert for a common-anode display
    seg_phys <= not seg_dec when SEG_ACTIVE_LOW else seg_dec;

    dp_out <= SEG_OFF(0);   -- decimal point kept off

    ---------------------------------------------------------------
    -- Multiplexer: on each 1 kHz tick all digits are switched off, the next
    -- digit's segments are loaded, then that one digit is enabled.
    -- Exactly one digit is on at a time (no ghosting).
    ---------------------------------------------------------------
    process(clk)
        variable nxt : integer range 0 to 3;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                dig_idx <= 0;
                phase   <= 2;
                sel_out <= (others => not SEL_ACTIVE);
                seg_out <= SEG_OFF;
            elsif mux_clk = '1' then
                if dig_idx = 3 then
                    nxt := 0;
                else
                    nxt := dig_idx + 1;
                end if;
                dig_idx <= nxt;
                sel_out <= (others => not SEL_ACTIVE);
                phase   <= 0;
            elsif phase = 0 then
                seg_out <= seg_phys;             -- new digit's segments, digits still off
                phase   <= 1;
            elsif phase = 1 then
                sel_out(dig_idx) <= SEL_ACTIVE;   -- D1 = S1 ... D4 = S4
                phase   <= 2;
            end if;
        end if;
    end process;

end architecture;
