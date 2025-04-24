-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2023 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Pavel Stepanov <xstepa77>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

--- CHARACTERS COUNTER --------------------------------------------------------

signal PC : std_logic_vector(12 downto 0);
signal PC_INC : std_logic;
signal PC_DEC : std_logic;

--- POINTER TO DATA -----------------------------------------------------------

signal PTR : std_logic_vector(12 downto 0);
signal PTR_INC : std_logic;
signal PTR_DEC : std_logic;

--- MULTIPLEXERS --------------------------------------------------------------

signal MUX1 : std_logic;
signal MUX2 : std_logic_vector(1 downto 0);

--- WHILE COUNTER -------------------------------------------------------------

signal CNT : std_logic_vector(7 downto 0);
signal CNT_INC : std_logic;
signal CNT_DEC : std_logic;
signal CNT_UNO : std_logic;

--- FSM STATES ----------------------------------------------------------------

type FSMstate is
	(S_RESET,
	S_FETCH, 
	DECODE,
	BEFOREIDLE, IDLE, AFTERIDLE,
	S_PTR_INC, S_PTR_DEC,
    VAL_INC1, VAL_INC2,
	VAL_DEC1, VAL_DEC2,
	PRINT1, PRINT2,
	LOAD1, LOAD2,
	WHILE1, WHILE2, WHILE3, WHILE4, WHILE5,
	WHILEEND1, WHILEEND2, WHILEEND3, WHILEEND4, WHILEEND5, WHILEEND6, 
	BREAK, BREAK2, BREAK3, 
	S_HALT);
signal P_STATE : FSMstate;
signal N_STATE : FSMstate;


--- PROGRAM -------------------------------------------------------------------
begin

--- PC reset, increment, decrement --------------------------------------------
process_PC: process (RESET, CLK, PC_INC, PC_DEC)
begin
	if(RESET = '1') then
		PC <= (others => '0');
	elsif (CLK'event) and (CLK = '1') then
		if(PC_INC='1') then
			PC <= PC + 1;
		elsif(PC_DEC='1') then
			PC <= PC - 1;
		end if;
	end if;
end process;

--- PTR reset, increment, decrement -------------------------------------------
process_PTR: process (RESET, CLK, PTR_INC, PTR_DEC)
begin
	if(RESET = '1') then
		PTR <= "0000000000000";
	elsif (rising_edge(CLK)) then
		if(PTR_INC='1') then
			PTR <= PTR + 1;
		elsif(PTR_DEC='1') then 
			PTR <= PTR - 1;
		end if;
	end if;
end process;

--- CNT reset, increment, decrement, changing to 1 ----------------------------
process_CNT : process (RESET, CLK, CNT_UNO, CNT_INC, CNT_DEC)
begin
	 if (RESET = '1') then
		  CNT <= "00000000";
	 elsif(CNT_UNO = '1') then
			CNT <= "00000001";
	 elsif (rising_edge(CLK)) then
		  if (CNT_INC = '1') then
			   CNT <= CNT + 1;
		  elsif (CNT_DEC = '1') then
			   CNT <= CNT - 1;
		  end if;
	 end if;
end process;

--- Multiplexer to swap address of commands and data --------------------------
with MUX1 select
	DATA_ADDR <= PTR when '0',
				 PC when '1',
				 "0000000000000" when others;

--- Multiplexer to increment or decrement value or to load data from input -----
with MUX2 select
	DATA_WDATA <= IN_DATA when "00",
				  (DATA_RDATA - 1) when "01",
			      (DATA_RDATA + 1) when "10",
			      "00000000" when others;

--- Declaration of states ------------------------------------------------------
process_states: process (RESET, CLK, EN)
begin
	if(RESET='1') then
		P_STATE <= S_RESET;
	elsif(rising_edge(CLK)) then
		P_STATE <= N_STATE;
	end if;
end process;


--- FSM -----------------------------------------------------------------------
nslogic: process(P_STATE, IN_VLD, OUT_BUSY, DATA_RDATA, CNT_UNO, EN)
begin

	IN_REQ <= '0';
	OUT_DATA <= "00000000";
	OUT_WE <= '0';
	PC_INC <= '0';
	PC_DEC <= '0';
	PTR_INC <= '0';
	PTR_DEC <= '0';
	CNT_INC <= '0';
	CNT_DEC <= '0';
	MUX1 <= '0';
	MUX2 <= "00";
	DATA_RDWR <= '0';
	DATA_EN <= '1';
    DONE <= '0';
    READY <= '1';
	CNT_UNO <= '0';

	case P_STATE is
		when S_RESET =>
			READY <= '0';
			N_STATE <= IDLE;
		when S_HALT =>
            READY <= '1';
            DONE <= '1';
			N_STATE <= S_HALT;
		when IDLE => 
			READY <= '0';
			if(DATA_RDATA = X"40") then
				DATA_EN <= '0';
				READY <= '1';
				N_STATE <= AFTERIDLE;
			else
				PTR_INC <= '1';
				N_STATE <= IDLE;
			end if;
		when AFTERIDLE => -- State to prevent ending of program before it starts
			MUX1 <= '1';
			N_STATE <= S_FETCH;
		when S_FETCH =>
			MUX1 <= '1';
			N_STATE <= DECODE;
		when DECODE =>
			MUX1 <= '1';
			case DATA_RDATA is
				when X"3E" =>  -- >
					N_STATE <= S_PTR_INC;
				when X"3C" =>  -- <
					N_STATE <= S_PTR_DEC;
				when X"2B" =>  -- +
					N_STATE <= VAL_INC1;
				when X"2D" =>  -- -
					N_STATE <= VAL_DEC1;
				when X"5B" =>  -- [
					N_STATE <= WHILE1;
				when X"5D" =>  -- ]
					N_STATE <= WHILEEND1;
				when X"7E" =>  -- ~
					N_STATE <= BREAK;
				when X"2E" =>  -- .
					N_STATE <= PRINT1;
				when X"2C" =>  -- ,
					N_STATE <= LOAD1;
				when X"40" =>  -- @
					N_STATE <= S_HALT;		
				when others =>
					PC_INC <= '1';
					N_STATE <= S_FETCH;
			end case;
	--- Pointer increment and decrement -----------------------------------------
		when S_PTR_INC =>
			PTR_INC <= '1';
			PC_INC <= '1';
			N_STATE <= S_FETCH;
		when S_PTR_DEC =>
			PTR_DEC <= '1';
			PC_INC <= '1';
			N_STATE <= S_FETCH;	
	
	--- Value increment ---------------------------------------------------------
		when VAL_INC1 =>
			N_STATE <= VAL_INC2;
		when VAL_INC2 =>
			MUX2 <= "10";
			DATA_RDWR <= '1';
			PC_INC <= '1';
			N_STATE <= S_FETCH;
	
	--- Value decrement ---------------------------------------------------------
		when VAL_DEC1 =>
			N_STATE <= VAL_DEC2;
		when VAL_DEC2 =>
			MUX2 <= "01";
			DATA_RDWR <= '1';
			PC_INC <= '1';
			N_STATE <= S_FETCH;

	--- Load data from input ----------------------------------------------------
		when LOAD1 =>
			IN_REQ <= '1';
			N_STATE <= LOAD2;
		when LOAD2 =>
			if(IN_VLD = '1') then
				MUX2 <= "00";
				DATA_RDWR <= '1';
				PC_INC <= '1';
				N_STATE <= S_FETCH;
			else 
				N_STATE <= LOAD1;
			end if;
		
	--- Print data to output ----------------------------------------------------
		when PRINT1 =>
			N_STATE <= PRINT2;
		when PRINT2 =>
			if(OUT_BUSY = '0') then
				OUT_WE <= '1';
				OUT_DATA <= DATA_RDATA;
				PC_INC <= '1';
				N_STATE <= S_FETCH;
			else
				N_STATE <= PRINT1;
			end if;	

	--- While loop [ ------------------------------------------------------------
		when WHILE1 =>
			PC_INC <= '1';                   
			N_STATE <= WHILE2;
   		when WHILE2 =>
			if (DATA_RDATA = X"00") then
				CNT_UNO <= '1';  
				N_STATE <= WHILE3;
			else
				CNT_INC <= '1';
				N_STATE <= S_FETCH;
			end if;
	--- LOOP --------------------------------------------------------------------
		when WHILE3 =>
			MUX1 <= '1';              
			N_STATE <= WHILE4;
		when WHILE4 =>
			if (DATA_RDATA = X"5B") then
				CNT_INC <= '1';
			elsif (DATA_RDATA = X"5D") then
				CNT_DEC <= '1';
			end if;
			N_STATE <= WHILE5;
		when WHILE5 =>
			if (CNT = X"00") then
				PC_INC <= '1';
				N_STATE <= S_FETCH;
			else
				PC_INC <= '1';
				N_STATE <= WHILE3;
			end if;

	--- While loop ] ------------------------------------------------------------
		when WHILEEND1 =>     
			N_STATE    <= WHILEEND2;
		when WHILEEND2 =>
			if (DATA_RDATA = X"00") then
				PC_INC   <= '1';
				MUX1  <= '1';
				N_STATE   <= S_FETCH;
			else
				MUX1 <= '1';   
				CNT_UNO <= '1';
				PC_DEC <= '1';
				N_STATE <= WHILEEND3;
			end if;
	--- LOOP --------------------------------------------------------------------
		when WHILEEND3 =>
			MUX1 <= '1';   
			N_STATE <= WHILEEND4;
		when WHILEEND4 =>
			MUX1 <= '1';
			if (DATA_RDATA = X"5D") then
				CNT_INC <= '1';
			elsif (DATA_RDATA = X"5B") then
				CNT_DEC <= '1';
			end if;
			N_STATE <= WHILEEND5;
		when WHILEEND5 =>
			MUX1 <= '1';        
			N_STATE <= WHILEEND6;
		when WHILEEND6 =>
			MUX1 <= '1';
			if (CNT = X"00") then
				PC_INC <= '1';
				N_STATE <= S_FETCH;
			else
				PC_DEC <= '1';
				N_STATE <= WHILEEND3;
			end if;
	
	--- Break loop ~ ------------------------------------------------------------
		when BREAK =>
			MUX1 <= '1';
			N_STATE <= BREAK2;
		when BREAK2 =>
			MUX1   <= '1';
			if (DATA_RDATA = X"5D") then
				PC_INC <= '1';
				CNT_DEC <= '1';
			elsif (DATA_RDATA = X"5B") then
				PC_INC <= '1';
				CNT_INC <= '1';
			end if;
			N_STATE <= BREAK3;
		when BREAK3 =>
			MUX1 <= '1';
			if(CNT = "00000000") then
				N_STATE <= S_FETCH;
			else
				PC_INC <= '1';
				N_STATE <= BREAK;
			end if;
				
		when others => null;	
				
				
	end case;		
end process;

end behavioral;