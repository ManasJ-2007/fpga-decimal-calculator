library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keypad_interface is
   port (
      clk       : in std_logic;
      reset     : in std_logic;
      row_in    : in std_logic_vector(3 downto 0);
      col_out   : out std_logic_vector(3 downto 0);
      led_out   : out std_logic_vector(3 downto 0);
      key_valid : out std_logic
   );
end entity;

architecture behavioral of keypad_interface is
   constant SETTLE_CYCLES  : integer := 500;
   constant DEBOUNCE_LIMIT : integer := 875000;

   type state_t is (IDLE, SCAN_COL1, SCAN_COL2, SCAN_COL3, SCAN_COL4,
                    KEY_PRESS, DEBOUNCE, KEY_RELEASE);
   signal state : state_t;

   signal cnt : integer range 0 to 1048575;
   signal internal_key_value : std_logic_vector(3 downto 0);

   signal row_sync_1 : std_logic_vector(3 downto 0);
   signal row_sync   : std_logic_vector(3 downto 0);

   signal col_sel : integer range 0 to 3;
   signal row_pat : std_logic_vector(3 downto 0);

   type pattern_array is array (1 to 4) of std_logic_vector(3 downto 0);
   constant PATTERN : pattern_array := ("1110", "1101", "1011", "0111");

   function ONE_ZERO(x : std_logic_vector(3 downto 0)) return boolean is
   begin
      return (x = "1110") or (x = "1101") or (x = "1011") or (x = "0111");
   end function;

   function KEY_CODE(row : std_logic_vector(3 downto 0); col : integer) return std_logic_vector is
   begin
      if col = 0 then
         if row = "1110" then return "0001";
         elsif row = "1101" then return "0100";
         elsif row = "1011" then return "0111";
         elsif row = "0111" then return "1110";
         end if;
      elsif col = 1 then
         if row = "1110" then return "0010";
         elsif row = "1101" then return "0101";
         elsif row = "1011" then return "1000";
         elsif row = "0111" then return "0000";
         end if;
      elsif col = 2 then
         if row = "1110" then return "0011";
         elsif row = "1101" then return "0110";
         elsif row = "1011" then return "1001";
         elsif row = "0111" then return "1111";
         end if;
      elsif col = 3 then
         if row = "1110" then return "1010";
         elsif row = "1101" then return "1011";
         elsif row = "1011" then return "1100";
         elsif row = "0111" then return "1101";
         end if;
      end if;
      return "0000";
   end function;

begin
   led_out <= internal_key_value;

   process(clk, reset)
   begin
      if reset = '1' then
         row_sync_1 <= "1111";
         row_sync <= "1111";
      elsif rising_edge(clk) then
         row_sync_1 <= row_in;
         row_sync <= row_sync_1;
      end if;
   end process;

   process(clk, reset)
   begin
      if reset = '1' then
         state <= IDLE;
         col_out <= "0000";
         key_valid <= '0';
         cnt <= 0;
         internal_key_value <= "0000";
         col_sel <= 0;
         row_pat <= "1111";
      elsif rising_edge(clk) then
         key_valid <= '0';

         case state is
            when IDLE =>
               col_out <= "0000";
               cnt <= 0;
               if row_sync /= "1111" then
                  state <= SCAN_COL1;
               end if;

            when SCAN_COL1 =>
               col_out <= PATTERN(1);
               if cnt < SETTLE_CYCLES - 1 then
                  cnt <= cnt + 1;
               else
                  cnt <= 0;
                  if ONE_ZERO(row_sync) then
                     col_sel <= 0;
                     row_pat <= row_sync;
                     state <= KEY_PRESS;
                  else
                     state <= SCAN_COL2;
                  end if;
               end if;

            when SCAN_COL2 =>
               col_out <= PATTERN(2);
               if cnt < SETTLE_CYCLES - 1 then
                  cnt <= cnt + 1;
               else
                  cnt <= 0;
                  if ONE_ZERO(row_sync) then
                     col_sel <= 1;
                     row_pat <= row_sync;
                     state <= KEY_PRESS;
                  else
                     state <= SCAN_COL3;
                  end if;
               end if;

            when SCAN_COL3 =>
               col_out <= PATTERN(3);
               if cnt < SETTLE_CYCLES - 1 then
                  cnt <= cnt + 1;
               else
                  cnt <= 0;
                  if ONE_ZERO(row_sync) then
                     col_sel <= 2;
                     row_pat <= row_sync;
                     state <= KEY_PRESS;
                  else
                     state <= SCAN_COL4;
                  end if;
               end if;

            when SCAN_COL4 =>
               col_out <= PATTERN(4);
               if cnt < SETTLE_CYCLES - 1 then
                  cnt <= cnt + 1;
               else
                  cnt <= 0;
                  if ONE_ZERO(row_sync) then
                     col_sel <= 3;
                     row_pat <= row_sync;
                     state <= KEY_PRESS;
                  else
                     state <= IDLE;
                  end if;
               end if;

            when KEY_PRESS =>
               col_out <= PATTERN(col_sel + 1);
               cnt <= 0;
               state <= DEBOUNCE;

            when DEBOUNCE =>
               col_out <= PATTERN(col_sel + 1);
               if row_sync /= row_pat then
                  state <= IDLE;
               elsif cnt = DEBOUNCE_LIMIT - 1 then
                  internal_key_value <= KEY_CODE(row_pat, col_sel);
                  key_valid <= '1';
                  cnt <= 0;
                  state <= KEY_RELEASE;
               else
                  cnt <= cnt + 1;
               end if;

            when KEY_RELEASE =>
               col_out <= "0000";
               if row_sync = "1111" then
                  if cnt = DEBOUNCE_LIMIT - 1 then
                     cnt <= 0;
                     state <= IDLE;
                  else
                     cnt <= cnt + 1;
                  end if;
               else
                  cnt <= 0;
               end if;
         end case;
      end if;
   end process;
end architecture;