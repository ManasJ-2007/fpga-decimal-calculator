library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.calc_pkg.all;

entity seven_seg_scroll is
    port (
        clk       : in std_logic;
        reset     : in std_logic;
        start     : in std_logic;                    -- not used
        data_in   : in rom_type;                     -- 8 codes from the ALU, data_in(0) is leftmost
        scroll_en : in std_logic;                    -- '0' = show data_in(0..3), '1' = scroll all 8
        seg_out   : out std_logic_vector(6 downto 0);
        dp_out    : out std_logic;                   -- decimal point, kept off
        sel_out   : out std_logic_vector(3 downto 0)
    );
end entity;

architecture behav of seven_seg_scroll is
    component clk_div is
        port (
            clk_in   : in  std_logic;
            rst      : in  std_logic;
            clk_1kHz : out std_logic;
            clk_2Hz  : out std_logic
        );
    end component;

    component seven_seg_decoder is
        port (
            code_in : in  std_logic_vector(3 downto 0);
            seg_out : out std_logic_vector(6 downto 0)
        );
    end component;

    signal clk_1kHz, clk_2Hz : std_logic;
    signal current_code : std_logic_vector(3 downto 0);  -- code sent to the decoder

    type state_t is (IDLE, SCROLL);                      -- IDLE = static, SCROLL = scrolling
    signal current_state : state_t := IDLE;

    type mux_state_t is (D1, D2, D3, D4);                -- which digit is lit now
    signal current_mux : mux_state_t := D1;

    signal offset : integer range 0 to 11 := 0;          -- how far the result has scrolled
    signal length : integer range 0 to 8 := 0;           -- number of digits in the result

begin

    dp_out <= '1';                                  -- DP off (active-low, common anode)

    clk_gen: clk_div port map (clk, reset, clk_1kHz, clk_2Hz);

    decoder_inst: seven_seg_decoder port map (
        code_in => current_code,
        seg_out => seg_out
    );

    -- Count digits: position of the last non-blank code
    process(data_in)
        variable n : integer range 0 to 8;
    begin
        n := 0;
        for i in 0 to 7 loop
            if data_in(i) /= "1111" then
                n := i + 1;
            end if;
        end loop;
        length <= n;
    end process;

    -- Scroll FSM (~2 Hz)
    process(clk_2Hz, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            offset <= 0;
        elsif rising_edge(clk_2Hz) then
            case current_state is
                when IDLE =>
                    offset <= 0;
                    if scroll_en = '1' then
                        current_state <= SCROLL;
                    end if;
                when SCROLL =>
                    if scroll_en = '0' then
                        current_state <= IDLE;
                        offset <= 0;
                    elsif offset >= length + 3 then     -- last digit has left, restart
                        offset <= 0;
                    else
                        offset <= offset + 1;
                    end if;
            end case;
        end if;
    end process;

    -- Multiplexer FSM (~1 kHz)
    process(clk_1kHz, reset)
    begin
        if reset = '1' then
            current_mux <= D1;
        elsif rising_edge(clk_1kHz) then
            case current_mux is
                when D1 => current_mux <= D2;
                when D2 => current_mux <= D3;
                when D3 => current_mux <= D4;
                when D4 => current_mux <= D1;
            end case;
        end if;
    end process;

    -- Output Routing
    process(current_mux, offset, scroll_en, data_in)
        variable pos : integer range 0 to 3;             -- digit position, 0 = leftmost
        variable idx : integer range -3 to 11;           -- data_in index shown at this position
    begin
        case current_mux is
            when D1 => sel_out <= "0001"; pos := 0;
            when D2 => sel_out <= "0010"; pos := 1;
            when D3 => sel_out <= "0100"; pos := 2;
            when D4 => sel_out <= "1000"; pos := 3;
        end case;

        if scroll_en = '0' then
            current_code <= data_in(pos);
        else
            idx := offset + pos - 3;
            if idx < 0 or idx > 7 then
                current_code <= "1111";                  -- outside the data, show blank
            else
                current_code <= data_in(idx);
            end if;
        end if;
    end process;

end behav;