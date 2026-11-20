library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.calc_pkg.all;

entity calculator_top is
   port (
      clk     : in  std_logic;
      reset   : in  std_logic;
      row_in  : in  std_logic_vector(3 downto 0);   -- keypad rows
      col_out : out std_logic_vector(3 downto 0);   -- keypad columns
      seg_out : out std_logic_vector(6 downto 0);   -- 7-segment a..g
      dp_out  : out std_logic;                      -- decimal point (kept off)
      sel_out : out std_logic_vector(3 downto 0)    -- digit select
   );
end entity;

architecture behav of calculator_top is

   signal internal_key   : std_logic_vector(3 downto 0);
   signal internal_valid : std_logic;
   signal internal_leds  : std_logic_vector(3 downto 0);

   type calc_state_t is (INIT, GET_OP1, SAVE_OP, GET_OP2, EXECUTE,
                         ERASE_DIGIT, CLEAR_ALL, DISPLAY_RESULT);
   signal current_calc_state : calc_state_t := INIT;

   -- EXECUTE is spread over several clock cycles (sub-steps of the EXECUTE state)
   type exec_phase_t is (X_LOAD, X_ALU, X_CONV, X_FMT);
   signal exec_phase : exec_phase_t := X_LOAD;

   type bcd_array_4 is array (0 to 3) of std_logic_vector(3 downto 0);
   signal op1_bcd, op2_bcd : bcd_array_4 := (others => "1111");

   signal operator      : std_logic_vector(3 downto 0) := "0000";
   signal is_op2        : std_logic := '0';

   signal display_data  : rom_type := (others => "1111");
   signal scroll_en_reg : std_logic := '0';

   -- ALU registers
   signal v1_reg  : integer range 0 to 9999 := 0;
   signal v2_reg  : integer range 0 to 9999 := 0;
   signal res_reg : integer range 0 to 99999999 := 0;
   signal neg_reg : std_logic := '0';

   -- binary -> BCD (double dabble) registers
   signal bin_sh : unsigned(26 downto 0) := (others => '0');
   signal bcd_sh : unsigned(31 downto 0) := (others => '0');
   signal dd_cnt : integer range 0 to 27 := 0;

   -- 4 BCD digits (index 3 = thousands, "1111" = empty) -> integer
   function bcd4_to_int(a : bcd_array_4) return integer is
      variable r : integer range 0 to 9999 := 0;
      type weights_t is array (0 to 3) of integer;
      constant W : weights_t := (1, 10, 100, 1000);   -- weight of a(i)
   begin
      r := 0;
      for i in 0 to 3 loop
         if a(i) /= "1111" then
            r := r + to_integer(unsigned(a(i))) * W(i);
         end if;
      end loop;
      return r;
   end function;

   component keypad_interface is
      port (
         clk       : in std_logic;
         reset     : in std_logic;
         row_in    : in std_logic_vector(3 downto 0);
         col_out   : out std_logic_vector(3 downto 0);
         led_out   : out std_logic_vector(3 downto 0);
         key_valid : out std_logic
      );
   end component;

   component seven_seg_scroll is
      port (
         clk       : in std_logic;
         reset     : in std_logic;
         start     : in std_logic;
         data_in   : in rom_type;
         scroll_en : in std_logic;
         seg_out   : out std_logic_vector(6 downto 0);
         dp_out    : out std_logic;
         sel_out   : out std_logic_vector(3 downto 0)
      );
   end component;

begin
   -- key code is valid in the same clock cycle as key_valid
   internal_key <= internal_leds;

   keypad_inst: keypad_interface
      port map (
         clk       => clk,
         reset     => reset,
         row_in    => row_in,
         col_out   => col_out,
         led_out   => internal_leds,
         key_valid => internal_valid
      );

   display_inst: seven_seg_scroll
      port map (
         clk       => clk,
         reset     => reset,
         start     => internal_valid,
         data_in   => display_data,
         scroll_en => scroll_en_reg,
         seg_out   => seg_out,
         dp_out    => dp_out,
         sel_out   => sel_out
      );

   process(clk, reset)
      variable v_bcd_arr : rom_type;
      variable v_leading : boolean;
      variable v_b       : unsigned(31 downto 0);
      variable v_n       : unsigned(3 downto 0);
   begin
      if reset = '1' then
         current_calc_state <= INIT;
         exec_phase    <= X_LOAD;
         op1_bcd       <= (others => "1111");
         op2_bcd       <= (others => "1111");
         display_data  <= (others => "1111");
         scroll_en_reg <= '0';
         is_op2        <= '0';
         operator      <= "0000";
         v1_reg        <= 0;
         v2_reg        <= 0;
         res_reg       <= 0;
         neg_reg       <= '0';
         bin_sh        <= (others => '0');
         bcd_sh        <= (others => '0');
         dd_cnt        <= 0;
      elsif rising_edge(clk) then

         case current_calc_state is

            when INIT =>
               op1_bcd       <= (others => "1111");
               op2_bcd       <= (others => "1111");
               display_data  <= (others => "1111");
               scroll_en_reg <= '0';
               is_op2        <= '0';
               operator      <= "0000";
               exec_phase    <= X_LOAD;
               current_calc_state <= GET_OP1;

            when GET_OP1 =>
               display_data(0) <= op1_bcd(3);
               display_data(1) <= op1_bcd(2);
               display_data(2) <= op1_bcd(1);
               display_data(3) <= op1_bcd(0);
               scroll_en_reg   <= '0';
               if op1_bcd(0) = "1111" then
                  display_data(3) <= "0000";            -- show 0 when empty
               end if;

               if internal_valid = '1' then
                  if internal_key = "1111" then                     -- #
                     current_calc_state <= CLEAR_ALL;
                  elsif internal_key = "1110" then                  -- *
                     current_calc_state <= ERASE_DIGIT;
                  elsif internal_key <= "1001" then                 -- digit 0-9
                     if op1_bcd(3) = "1111" then                    -- not full
                        op1_bcd(3) <= op1_bcd(2);
                        op1_bcd(2) <= op1_bcd(1);
                        op1_bcd(1) <= op1_bcd(0);
                        op1_bcd(0) <= internal_key;
                     end if;
                  elsif internal_key >= "1010" and internal_key <= "1100" then  -- A B C
                     operator <= internal_key;
                     current_calc_state <= SAVE_OP;
                  end if;
               end if;

            when SAVE_OP =>
               is_op2 <= '1';
               current_calc_state <= GET_OP2;

            when GET_OP2 =>
               display_data(0) <= op2_bcd(3);
               display_data(1) <= op2_bcd(2);
               display_data(2) <= op2_bcd(1);
               display_data(3) <= op2_bcd(0);
               if op2_bcd(0) = "1111" then
                  display_data(3) <= "0000";
               end if;

               if internal_valid = '1' then
                  if internal_key = "1111" then                     -- #
                     current_calc_state <= CLEAR_ALL;
                  elsif internal_key = "1110" then                  -- *
                     current_calc_state <= ERASE_DIGIT;
                  elsif internal_key <= "1001" then                 -- digit 0-9
                     if op2_bcd(3) = "1111" then
                        op2_bcd(3) <= op2_bcd(2);
                        op2_bcd(2) <= op2_bcd(1);
                        op2_bcd(1) <= op2_bcd(0);
                        op2_bcd(0) <= internal_key;
                     end if;
                  elsif internal_key = "1101" then                  -- D (=)
                     exec_phase <= X_LOAD;
                     current_calc_state <= EXECUTE;
                  end if;
               end if;

            when ERASE_DIGIT =>
               if is_op2 = '0' then
                  op1_bcd(0) <= op1_bcd(1);
                  op1_bcd(1) <= op1_bcd(2);
                  op1_bcd(2) <= op1_bcd(3);
                  op1_bcd(3) <= "1111";
                  current_calc_state <= GET_OP1;
               else
                  op2_bcd(0) <= op2_bcd(1);
                  op2_bcd(1) <= op2_bcd(2);
                  op2_bcd(2) <= op2_bcd(3);
                  op2_bcd(3) <= "1111";
                  current_calc_state <= GET_OP2;
               end if;

            when CLEAR_ALL =>
               op1_bcd       <= (others => "1111");
               op2_bcd       <= (others => "1111");
               display_data  <= (others => "1111");
               operator      <= "0000";
               scroll_en_reg <= '0';
               is_op2        <= '0';
               exec_phase    <= X_LOAD;
               current_calc_state <= GET_OP1;

            ----------------------------------------------------------------
            -- EXECUTE: one small step per clock cycle
            ----------------------------------------------------------------
            when EXECUTE =>
               case exec_phase is

                  -- 1) operands: BCD digits -> binary
                  when X_LOAD =>
                     v1_reg <= bcd4_to_int(op1_bcd);
                     v2_reg <= bcd4_to_int(op2_bcd);
                     exec_phase <= X_ALU;

                  -- 2) ALU: add / subtract (magnitude + sign) / multiply
                  when X_ALU =>
                     neg_reg <= '0';
                     if operator = "1010" then
                        res_reg <= v1_reg + v2_reg;
                     elsif operator = "1011" then
                        if v1_reg < v2_reg then
                           res_reg <= v2_reg - v1_reg;
                           neg_reg <= '1';
                        else
                           res_reg <= v1_reg - v2_reg;
                        end if;
                     elsif operator = "1100" then
                        res_reg <= v1_reg * v2_reg;
                     else
                        res_reg <= 0;
                     end if;
                     dd_cnt     <= 0;
                     exec_phase <= X_CONV;

                  -- 3) binary -> BCD by double dabble (27 shift steps)
                  when X_CONV =>
                     if dd_cnt = 0 then
                        bin_sh <= to_unsigned(res_reg, 27);
                        bcd_sh <= (others => '0');
                        dd_cnt <= 1;
                     else
                        v_b := bcd_sh;
                        for i in 0 to 7 loop
                           v_n := v_b(4*i+3 downto 4*i);
                           if v_n >= 5 then
                              v_b(4*i+3 downto 4*i) := v_n + 3;
                           end if;
                        end loop;
                        bcd_sh <= v_b(30 downto 0) & bin_sh(26);
                        bin_sh <= bin_sh(25 downto 0) & '0';
                        if dd_cnt = 27 then
                           exec_phase <= X_FMT;
                        else
                           dd_cnt <= dd_cnt + 1;
                        end if;
                     end if;

                  -- 4) format: zero suppression, minus sign, window / scroll
                  when X_FMT =>
                     for i in 0 to 7 loop
                        v_bcd_arr(i) := std_logic_vector(bcd_sh(31 - 4*i downto 28 - 4*i));
                     end loop;

                     v_leading := true;
                     for i in 0 to 7 loop
                        if v_leading and v_bcd_arr(i) = "0000" and i < 7 then
                           v_bcd_arr(i) := "1111";
                        else
                           v_leading := false;
                        end if;
                     end loop;

                     if neg_reg = '1' then
                        for i in 1 to 7 loop
                           if v_bcd_arr(i) /= "1111" and v_bcd_arr(i-1) = "1111" then
                              v_bcd_arr(i-1) := "1010";
                              exit;
                           end if;
                        end loop;
                     end if;

                     if res_reg > 9999 or (neg_reg = '1' and res_reg > 999) then
                        -- does not fit in 4 positions: left-align and scroll
                        for step in 0 to 7 loop
                           if v_bcd_arr(0) = "1111" then
                              for k in 0 to 6 loop
                                 v_bcd_arr(k) := v_bcd_arr(k+1);
                              end loop;
                              v_bcd_arr(7) := "1111";
                           end if;
                        end loop;
                        display_data  <= v_bcd_arr;
                        scroll_en_reg <= '1';
                     else
                        display_data  <= (others => "1111");
                        display_data(0) <= v_bcd_arr(4);
                        display_data(1) <= v_bcd_arr(5);
                        display_data(2) <= v_bcd_arr(6);
                        display_data(3) <= v_bcd_arr(7);
                        scroll_en_reg <= '0';
                     end if;

                     exec_phase <= X_LOAD;
                     current_calc_state <= DISPLAY_RESULT;

               end case;

            when DISPLAY_RESULT =>
               if internal_valid = '1' and internal_key = "1111" then
                  current_calc_state <= CLEAR_ALL;
               end if;

         end case;
      end if;
   end process;

end architecture;