----------------------------------------------------------------------------------
-- Company: Politecnico di Milano
-- Engineer: Luca Vecchio
-- 
-- Module Name: project_reti_logiche - Behavioral
-- Project Name: Progetto di Reti Logiche
-- Target Devices: FPGA xc7a200tfbg484-1
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
port (
      i_clk         : in  std_logic;
      i_start       : in  std_logic;
      i_rst         : in  std_logic;
      i_data        : in  std_logic_vector(7 downto 0);
      o_address     : out std_logic_vector(15 downto 0);
      o_done        : out std_logic;
      o_en          : out std_logic;
      o_we          : out std_logic;
      o_data        : out std_logic_vector (7 downto 0)
      );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    type stateType is (Idle, RequestMem, GetMem, RequestAddr, Compute, WaitStartZero, WaitRestart);
    type WZ_memoryType is array (0 to 7) of unsigned(7 downto 0);
    signal state_current, state_next : stateType := Idle;
    signal wz_memory : WZ_memoryType;
    signal counter : integer range 0 to 8 := 0;

begin
    status : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            state_current <= Idle;
        elsif rising_edge(i_clk) then
            state_current <= state_next;
        end if;
    end process;

    output : process(i_clk)
    variable wz_output_offset : std_logic_vector (3 downto 0);
    variable wz_output_zone : std_logic_vector (2 downto 0);
    variable wz_bit : bit := '0';
    variable wait_bit : bit := '0';
    begin
        if rising_edge(i_clk) then
            o_done <= '0';
            o_en <= '0';
            o_we <= '0';
            o_data <= (7 downto 0 => '0');
            o_address <= (15 downto 0 => '0');

            case state_current is
                when Idle => 
                    if i_start = '0' then
                        state_next <= Idle;
                    else
                        state_next <= RequestMem;
                    end if;
           
                when RequestMem =>
                    state_next <= GetMem;
                    o_en <= '1';
                    o_address <= (15 downto 3 => '0') & std_logic_vector(to_unsigned(counter, 3));
                    wait_bit := '0';
                
                when GetMem =>
                    if wait_bit = '0' then
                        if counter /= 7 then
                            state_next <= RequestMem;
                        else
                            state_next <= RequestAddr;
                        end if;
                        wz_memory(counter) <= unsigned(i_data);
                        counter <= counter + 1;
                        wait_bit := '1';
                    end if;

                when RequestAddr =>
                    state_next <= Compute;
                    o_en <= '1';
                    o_address <= "0000000000001000";
                    counter <= 0;

                when Compute =>
                    state_next <= WaitStartZero;
                    for k in 0 to 7 loop
                        if unsigned(i_data) < wz_memory(k) or unsigned(i_data) > wz_memory(k) + 3 then
                            next;
                        else
                            wz_bit := '1';
                            wz_output_zone := std_logic_vector(to_unsigned(k, 3));
                            -- codifica one-hot di wz_output_offset:
                            case unsigned(i_data) - wz_memory(k) is
                                when "00000000" =>    wz_output_offset := "0001";
                                when "00000001" =>    wz_output_offset := "0010";
                                when "00000010" =>    wz_output_offset := "0100";
                                when others =>        wz_output_offset := "1000";
                            end case;
                            exit;
                        end if;
                    end loop;

                    o_address <= "0000000000001001";
                    o_en <= '1';
                    o_we <= '1';
                    o_done <= '1';
                    if wz_bit = '1' then
                        o_data <= '1' & wz_output_zone & wz_output_offset;
                    else
                        o_data <= '0' & i_data(6 downto 0);
                    end if;
                
                when WaitStartZero =>
                    wz_bit := '0';
                    counter <= 0;
                    if i_start = '1' then
                        state_next <= WaitStartZero;
                        o_done <= '1';
                    else
                        o_done <= '0';
                        state_next <= WaitRestart;
                    end if;
                
                when WaitRestart =>
                if i_start = '1' then
                    state_next <= RequestAddr;
                end if;
            end case;

        end if;
    end process;
end Behavioral;
