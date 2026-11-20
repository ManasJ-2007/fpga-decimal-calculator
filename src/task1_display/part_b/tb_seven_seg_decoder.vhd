library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_seven_seg_decoder is
end entity;

architecture sim of tb_seven_seg_decoder is

    signal code_in : std_logic_vector(3 downto 0) := "0000";
    signal seg_out : std_logic_vector(6 downto 0);

    type seg_tbl_t is array (0 to 10) of std_logic_vector(6 downto 0);
    constant TBL : seg_tbl_t := (
        "1111110", "0110000", "1101101", "1111001", "0110011",
        "1011011", "1011111", "1110000", "1111111", "1111011",
        "0000001");                                  -- index 10 = minus

begin

    uut : entity work.seven_seg_decoder
        port map (code_in => code_in, seg_out => seg_out);

    process
        variable errors   : integer := 0;
        variable expected : std_logic_vector(6 downto 0);
    begin
        for i in 0 to 15 loop
            code_in <= std_logic_vector(to_unsigned(i, 4));
            wait for 10 ns;
            if i <= 10 then
                expected := TBL(i);
            else
                expected := "0000000";               -- 1011..1111 = blank
            end if;
            if seg_out /= expected then
                report "Code " & integer'image(i) & " wrong" severity error;
                errors := errors + 1;
            end if;
        end loop;

        if errors = 0 then
            report "DECODER: ALL 16 CODES PASSED" severity note;
        else
            report integer'image(errors) & " DECODER ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture;
