library ieee;
use ieee.std_logic_1164.all;

entity clk_divider is
    generic (CLK_FREQ : integer := 50_000_000);
    port (
        clk         : in  std_logic;   -- board oscillator
        reset       : in  std_logic;
        tick_mux    : out std_logic;   -- 1-cycle pulse at 1 kHz
        tick_scroll : out std_logic    -- 1-cycle pulse at 2 Hz
    );
end entity;

architecture rtl of clk_divider is
    constant MUX_MAX    : integer := CLK_FREQ/1000 - 1;
    constant SCROLL_MAX : integer := CLK_FREQ/2 - 1;
    signal mux_cnt    : integer range 0 to MUX_MAX    := 0;
    signal scroll_cnt : integer range 0 to SCROLL_MAX := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            tick_mux    <= '0';
            tick_scroll <= '0';
            if reset = '1' then
                mux_cnt    <= 0;
                scroll_cnt <= 0;
            else
                if mux_cnt = MUX_MAX then
                    mux_cnt  <= 0;
                    tick_mux <= '1';
                else
                    mux_cnt <= mux_cnt + 1;
                end if;

                if scroll_cnt = SCROLL_MAX then
                    scroll_cnt  <= 0;
                    tick_scroll <= '1';
                else
                    scroll_cnt <= scroll_cnt + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
