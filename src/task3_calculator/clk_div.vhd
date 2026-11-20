library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_div is
   port (
      clk_in   : in  std_logic;
      rst      : in  std_logic;
      clk_1kHz : out std_logic;
      clk_2Hz  : out std_logic
   );
end clk_div;

architecture behav of clk_div is
   constant MAX_1KHZ : integer := 24999;
   constant MAX_2HZ  : integer := 12499999;

   signal count_1kHz : integer range 0 to MAX_1KHZ := 0;
   signal count_2Hz  : integer range 0 to MAX_2HZ := 0;

   signal clk_1kHz_int : std_logic := '0';
   signal clk_2Hz_int  : std_logic := '0';

begin
   process(clk_in, rst)
   begin
      if rst = '1' then
         count_1kHz   <= 0;
         count_2Hz    <= 0;
         clk_1kHz_int <= '0';
         clk_2Hz_int  <= '0';
      elsif rising_edge(clk_in) then
         if count_1kHz = MAX_1KHZ then
            count_1kHz   <= 0;
            clk_1kHz_int <= not clk_1kHz_int;
         else
            count_1kHz <= count_1kHz + 1;
         end if;

         if count_2Hz = MAX_2HZ then
            count_2Hz   <= 0;
            clk_2Hz_int <= not clk_2Hz_int;
         else
            count_2Hz <= count_2Hz + 1;
         end if;
      end if;
   end process;

   clk_1kHz <= clk_1kHz_int;
   clk_2Hz  <= clk_2Hz_int;

end behav;