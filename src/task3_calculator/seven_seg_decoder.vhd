library ieee;
use ieee.std_logic_1164.all;

entity seven_seg_decoder is
	port (
	   code_in : in  std_logic_vector(3 downto 0);
	   seg_out : out std_logic_vector(6 downto 0)
	);
end entity;

architecture behavioral of seven_seg_decoder is
begin
	process(code_in)
	begin
	case code_in is -- seg_out mapped as [a, b, c, d, e, f, g]
		when "0000" => seg_out <= "0000001"; -- 0
		when "0001" => seg_out <= "1001111"; -- 1
		when "0010" => seg_out <= "0010010"; -- 2
		when "0011" => seg_out <= "0000110"; -- 3
		when "0100" => seg_out <= "1001100"; -- 4
		when "0101" => seg_out <= "0100100"; -- 5
		when "0110" => seg_out <= "0100000"; -- 6
		when "0111" => seg_out <= "0001111"; -- 7
		when "1000" => seg_out <= "0000000"; -- 8
		when "1001" => seg_out <= "0000100"; -- 9
		when "1010" => seg_out <= "1111110"; -- Minus sign (-)
		when others => seg_out <= "1111111"; -- Blank / Off
		end case;
	end process;
end architecture;