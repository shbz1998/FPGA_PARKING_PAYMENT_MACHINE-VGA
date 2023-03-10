LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE std.textio.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL;

ENTITY top IS
  PORT (
    CLK_I : IN STD_LOGIC;
    VGA_HS_O : OUT STD_LOGIC;
    VGA_VS_O : OUT STD_LOGIC;
    VGA_R : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
    VGA_B : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
    VGA_G : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
    row : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    col : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    rst : IN STD_LOGIC
  );
END top;
ARCHITECTURE Behavioral OF top IS


  
  COMPONENT blk_mem_gen_0
    PORT (
      addra : STD_LOGIC_VECTOR(6 DOWNTO 0);
      clka : IN STD_LOGIC;
      douta : OUT STD_LOGIC_VECTOR(783 DOWNTO 0);
      ena : IN STD_LOGIC
    );
  END COMPONENT;

  COMPONENT clk_wiz_0
    PORT (-- Clock in ports
      CLK_IN1 : IN STD_LOGIC;
      -- Clock out ports
      CLK_OUT1 : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT Decoder IS
    PORT (
      clk : IN STD_LOGIC;
      rst : IN STD_LOGIC;
      Row : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
      Col : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
      DecodeOut : OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
    );
  END COMPONENT;

  CONSTANT clk_freq : INTEGER := 50_000_000;
  CONSTANT stable_time : INTEGER := 10;

  --***1920x1080@60Hz***-- Requires 148.5 MHz pxl_clk
  CONSTANT FRAME_WIDTH : NATURAL := 1920;
  CONSTANT FRAME_HEIGHT : NATURAL := 1080;

  CONSTANT H_FP : NATURAL := 88; --H front porch width (pixels)
  CONSTANT H_PW : NATURAL := 44; --H sync pulse width (pixels)
  CONSTANT H_MAX : NATURAL := 2200; --H total period (pixels)

  CONSTANT V_FP : NATURAL := 4; --V front porch width (lines)
  CONSTANT V_PW : NATURAL := 5; --V sync pulse width (lines)
  CONSTANT V_MAX : NATURAL := 1125; --V total period (lines)
  CONSTANT H_POL : STD_LOGIC := '1';
  CONSTANT V_POL : STD_LOGIC := '1';

  --Moving Box constants
  CONSTANT BOX_WIDTH : NATURAL := 30;
  CONSTANT BOX_CLK_DIV : NATURAL := 5000; --MAX=(2^25 - 1)

  SIGNAL DIGIT_DETECT: STD_LOGIC;
  SIGNAL pixel_in_box2 : STD_LOGIC;
  SIGNAL pixel_in_box3 : STD_LOGIC;
  SIGNAL pixel_in_box4 : STD_LOGIC;
  SIGNAL pixel_in_box5 : STD_LOGIC;
  SIGNAL pixel_in_box6 : STD_LOGIC;
  SIGNAL pixel_in_box7 : STD_LOGIC;
  SIGNAL pixel_in_box8 : STD_LOGIC;
  SIGNAL pixel_in_box9: STD_LOGIC;
  
  SIGNAL pulse : STD_LOGIC_VECTOR(3 DOWNTO 0);

  CONSTANT BOX_X_MAX : NATURAL := (FRAME_WIDTH);
  CONSTANT BOX_Y_MAX : NATURAL := (FRAME_HEIGHT);

  CONSTANT BOX_X_MIN : NATURAL := 0;
  CONSTANT BOX_Y_MIN : NATURAL := 0;

  CONSTANT BOX_X_INIT : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"000";
  CONSTANT BOX_Y_INIT : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"190"; --400

  SIGNAL pxl_clk : STD_LOGIC;
  SIGNAL active : STD_LOGIC;

  SIGNAL h_cntr_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL v_cntr_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
  SIGNAL v_cntr_reg2 : STD_LOGIC_VECTOR(110 DOWNTO 0) := (OTHERS => '0');
  SIGNAL h_cntr_reg2 : STD_LOGIC_VECTOR(110 DOWNTO 0) := (OTHERS => '0');

  SIGNAL vert_count : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
  SIGNAL horz_count : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
  SIGNAL h_sync_reg : STD_LOGIC := NOT(H_POL);
  SIGNAL v_sync_reg : STD_LOGIC := NOT(V_POL);

  SIGNAL h_sync_dly_reg : STD_LOGIC := NOT(H_POL);
  SIGNAL v_sync_dly_reg : STD_LOGIC := NOT(V_POL);

  SIGNAL vga_red_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL vga_green_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL vga_blue_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL vga_red : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL vga_green : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL vga_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);

  SIGNAL box_x_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := BOX_X_INIT;
  SIGNAL box_x_dir : STD_LOGIC := '1';
  SIGNAL box_y_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := BOX_Y_INIT;
  SIGNAL box_y_dir : STD_LOGIC := '1';
  SIGNAL box_cntr_reg : STD_LOGIC_VECTOR(24 DOWNTO 0) := (OTHERS => '0');
  SIGNAL update_box : STD_LOGIC;
  SIGNAL pixel_in_box : STD_LOGIC;
  SIGNAL Y: INTEGER;

  SIGNAL img_pixel : STD_LOGIC;
  SIGNAL number_save : STD_LOGIC_VECTOR(3 downto 0);

  SIGNAL dig_sel : STD_LOGIC := '0';
  
  SIGNAL i : NATURAL := 0;

  SIGNAL ena : STD_LOGIC := '1';

  SIGNAL decode : STD_LOGIC_VECTOR (3 DOWNTO 0);

  CONSTANT m : NATURAL := 28;
  CONSTANT n : NATURAL := 28;

  SIGNAL TIMER : INTEGER;
  SIGNAL c : STD_LOGIC_VECTOR((m + n) - 1 DOWNTO 0);
  SIGNAL a : STD_LOGIC_VECTOR (m - 1 DOWNTO 0);
  SIGNAL b : STD_LOGIC_VECTOR (m - 1 DOWNTO 0);
  SIGNAL vert, horz : INTEGER;
  SIGNAL upper_bound : NATURAL := 0;
  SIGNAL lower_bound : NATURAL := 0;

  SIGNAL douta : STD_LOGIC_VECTOR(783 DOWNTO 0);
  SIGNAL addra : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL addr1 : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL addr2 : STD_LOGIC_VECTOR(6 DOWNTO 0);
  
  SIGNAL doutb : STD_LOGIC_VECTOR(783 DOWNTO 0);
  SIGNAL addrb : STD_LOGIC_VECTOR(6 DOWNTO 0);
  
  SIGNAL NUM_OF_DAYS: STD_LOGIC_VECTOR(3 DOWNTO 0);

  TYPE ROM_TYPE IS ARRAY (0 TO 13) OF STD_LOGIC_VECTOR(0 TO 105);

  TYPE ROM_TYPE2 IS ARRAY (0 TO 12) OF STD_LOGIC_VECTOR(0 TO 93);

  TYPE ROM_TYPE3 IS ARRAY (0 TO 17) OF STD_LOGIC_VECTOR(0 TO 65);

  TYPE ROM_TYPE4 IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(0 TO 47);

  TYPE ROM_TYPE5 IS ARRAY (0 TO 29) OF STD_LOGIC_VECTOR(0 TO 67);

  TYPE ROM_TYPE6 IS ARRAY (0 TO 69) OF STD_LOGIC_VECTOR(0 TO 66);

  TYPE ROM_TYPE7 IS ARRAY (0 TO 27) OF STD_LOGIC_VECTOR(0 TO 27);
  
  TYPE ROM_TYPE8 IS ARRAY (0 TO 12) OF STD_LOGIC_VECTOR(0 TO 53);
  

  CONSTANT DAYS_PIXEL: ROM_TYPE8:=
  (
"000000000000000000000000000000000000000000000000000000",
"000000000000000000000000000000000000000000000000000000",
"000000000000000000000000000000000000000000000000000000",
"000011000100111110000000111110000110011001011110000000",
"000011100101100011000000110011001110001011010000000000",
"000011100101100011000000110001001010001110011000110000",
"000011010101000011000000110001001011000110001110000000",
"000011011101100011000000110001011111000100000010000000",
"000011001101100010010000110011010001100100000010000000",
"000010001100111100010000111110010001100100011110110000",
"000000000000000000000000000000000000000000000000000000",
"000000000000000000000000000000000000000000000000000000",
"000000000000000000000000000000000000000000000000000000"
 );

  SIGNAL img: ROM_TYPE7;
  SIGNAL img2: ROM_TYPE7;

  SIGNAL a0 : NATURAL := 0; -- 0 to 9
  SIGNAL a1 : NATURAL := 10;
  SIGNAL a2 : NATURAL := 20;
  SIGNAL a3 : NATURAL := 30;
  SIGNAL a4 : NATURAL := 40;
  SIGNAL a5 : NATURAL := 50;
  SIGNAL a6 : NATURAL := 60;
  SIGNAL a7 : NATURAL := 70;
  SIGNAL a8 : NATURAL := 80;
  SIGNAL a9 : NATURAL := 90;

  CONSTANT OPTION : ROM_TYPE6 :=
  (
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000010000000100000001000000100001000111100010000000111000000000",
  "0000000111000000100000011000000110001001101110010001101101100000000",
  "0000000011000000110000001000000110001011000010010001101100100000000",
  "0000000011000000110000001000000110011011000010010001101101100000000",
  "0000000011000000010000001000000111111011000010010001101111000000000",
  "0000000011000000010000001000000110001011000010010001101101100000000",
  "0000000011000000110000001000000110001001000110010001101100100000000",
  "0000000111100100110000111110000110001001111100011111001100110000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000010000000100000011000000000000000011000000000000000000000000",
  "0000001111100000100000111100000110001001111100010001101111100000000",
  "0000000001100000110000000110000110001001000110010001101100100000000",
  "0000000001100000110000000110000110011011000010010001101100100000000",
  "0000000001000000010000001100000111111011000010010001101111100000000",
  "0000000011000000010000001000000110011011000010010001101101100000000",
  "0000000110000000110000010000000110001011000010010001101100100000000",
  "0000001111100100110000111110000110001001111110011111001100110000000",
  "0000000111100100110000111110000000000000111000001110000000000000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000111100000100000001100000110001001111100010001101111100000000",
  "0000000001100000110000011100000110001001000110010001101100100000000",
  "0000000001100000110000010100000110001011000010010001101100100000000",
  "0000000111000000010000110100000111111011000010010001101111100000000",
  "0000000001100000010000100100000110011011000010010001101101100000000",
  "0000000000100000010000111110000110001011000010010001101100100000000",
  "0000001101100100110000000100000110001001101110011011001100110000000",
  "0000000111000100110000000100000100001000111100001110000100010000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000001100000100000001100011000110000001111100001100010001100000",
  "0000000011100000110000001100011000110000001100110001110011001000000",
  "0000000111100000110000011110011000110000001100010001010001011000000",
  "0000000101100000110000010110011000110000001100010011010001110000000",
  "0000001101100000010000110010011000110000001100010010011000110000000",
  "0000001111110000010000111111011000110000001100010011111000100000000",
  "0000000001100100110000100011011000110000001100110110001000100000000",
  "0000000001000100110000100001011110111100001111000100001100100000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000100000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000",
  "0000000000000000000000000000000000000000000000000000000000000000000"
  );

  CONSTANT TRANSAC : ROM_TYPE5 :=
  (
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000111111011110000110001100010011110001100000111000000000000000000",
  "00000001100010011000110001110010010000001100001000100000000000000000",
  "00000001100010011001111001110010010000011110011000000000000000000000",
  "00000001100011110001001001111010011100010010011000000000000000000000",
  "00000001100011110001001001101010000110010011011000000000000000000000",
  "00000001100010010011111101101110000010111111011000000000000000000000",
  "00000001100010011010000101100110010110100001001101101000000000000000",
  "00000001100010001010000101100010011100100001000111001000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000",
  "00000001111000110001100010001111001111011000110001111101111100000000",
  "00000011001000110001110010011001011000011000110001100001100110000000",
  "00000010000001111001110010010000011000011000110001100001100010000000",
  "00000010000001001001111010010000011110011000110001111001100010000000",
  "00000010000001001001101010010000011000011000110001100001100010000000",
  "00000010000011111101101110010000011000011000110001100001100010000000",
  "00000011001010000101100110011001011000011000110001100001100110000000",
  "00000001111010000101100010001111001111011110011100111101111000000000",
  "00000000000000000000000000000000000000000000000000000000000000000000"
  );

  CONSTANT INSERT_CARD : ROM_TYPE4 :=
  (
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000100010000100011100011110011110011111100000",
  "000000110011000100110100111110011111001111100000",
  "000000110011100100100000110000010001000010000000",
  "000000110010100100110000110000010011000010000000",
  "000000110010110100011100111110011110000010000000",
  "000000110010010100000110110000010010000010000000",
  "000000110010011100000110110000010011000010000000",
  "000000110010001100100110110000010001000010000000",
  "000000110010001100111100011110010001100010000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000001110000110000111100001111000000000000000",
  "000000011011000111000110110011001100000000000000",
  "000000110000000111000110010011000110000000000000",
  "000000100000001101000110010011000110000000000000",
  "000000100000001001100111100011000010000000000000",
  "000000100000001111100110110011000110000000000000",
  "000000110000011111100110010011000110000000000000",
  "000000011011010000110110011011001100000000000000",
  "000000001110010000010100001001111000000000000000",
  "000000000000000000000000000000000000000000000000",
  "000000000000000000000000000000000000000000000000"
  );

  CONSTANT PAYMENT_ACC : ROM_TYPE3 :=
  (
  "000000111100000110001000010110000001100111100110001101111110000000",
  "000000110110000110001100110111000011100100000111001100011000000000",
  "000000110011001111000100100111000011100100000111001100011000000000",
  "000000110011001011000111100111100111100100000111101100011000000000",
  "000000111110011001000011000110100101100111100110101100011000000000",
  "000000111000011111100011000110111101100100000110111100011000000000",
  "000000110000011111100011000110111001100100000110011100011000000000",
  "000000110000110000100011000110011001100111100110011100011000000000",
  "000000100000100000110011000110011001100111100100001100001000000000",
  "000000001100000111100011110011111001111001111110111110011110000000",
  "000000001100001100110110001011000001001100011000110000110011100000",
  "000000011110001000000100000011000001000100011000100000110001100000",
  "000000010010011000000100000011110001001100011000111100110000100000",
  "000000010011011000001100000011110001111000011000111100110000100000",
  "000000111111011000000100000011000001100000011000100000110000100000",
  "000000110111001000000110000011000001000000011000100000110001100000",
  "000001100001101111110111111011111001000000011000111110111111000000",
  "000000000000100011100001110011111001000000010000111110011100000000"
  );

  CONSTANT ENTER_LIC : ROM_TYPE2 :=
  (
  "0000001111111000111000001101111111111001111111001111110000000000100000001100000111111000000000",
  "0000001111111000111000001100111111110011111110001111111100000000110000001100001110011100000000",
  "0000001100000000111100001100000110000011000000001100001100000000110000001100011100000000000000",
  "0000001100000000111100001100000110000011000000001100001100000000110000001100011000000000000000",
  "0000001100000000110110001100000110000011000000001100001100000000110000001100011000000000000000",
  "0000001111110000110110001100000110000011111110001110111000000000110000001100110000000000000000",
  "0000001111110000110011001100000110000011111110001111110000000000110000001100110000000000000000",
  "0000001100000000110011001100000110000011000000001100111000000000110000001100110000000000000000",
  "0000001100000000110001101100000110000011000000001100011000000000110000001100011000000000000000",
  "0000001100000000110001111100000110000011000000001100001100000000110000001100011000000000000000",
  "0000001100000000110000111100000110000011000000001100001100000000110000001100011100001100000000",
  "0000001111111000110000011100000110000011111111001100000110000000111111001100001111111100000000",
  "0000001111111000110000011000000110000001111111001100000110000000111111001100000011110000000000"

  );

  CONSTANT WELCOME : ROM_TYPE :=
  (
  "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "0000000001100000110000001000111111100110000000001111110000111111100000111000000001110001111111000000000000",
  "0000000001100000111000011000110000000110000000011100110001110001110000111000000011110001100000000000000000",
  "0000000001100000111000011000110000000110000000110000000001100000111000111100000011110001100000000000000000",
  "0000000000110001111000011000110000000110000000110000000011000000011000111100000110110001100000000000000000",
  "0000000000110001101000010000110000000110000001100000000011000000011000110110000110110001100000000000000000",
  "0000000000110001001100110000111111000110000001100000000011000000011000110110000100110001111110000000000000",
  "0000000000010001001100110000111111000110000001100000000011000000011000110110001100110001111110000000000000",
  "0000000000011011001100110000110000000110000001100000000011000000011000110011001100110001100000000000000000",
  "0000000000011011000100100000110000000110000001100000000011000000011000110011011000110001100000000000000000",
  "0000000000011010000111100000110000000110000000110000000011000000011000110001111000110001100000000000000000",
  "0000000000001110000111100000110000000110000000111000010001100000110000110001110000110001100000000000000000",
  "0000000000001110000111000000111111100111111100011111110000111111100000110001110000110001111111000000000000",
  "0000000000000100000011000000111111100011111100000111100000011111000000100000100000100001111111000000000000"
  );

  --STATE MACHINE LOGIC

  --
  TYPE STATE_TYPE IS(ST0, ST1, ST2, ST3, ST4, ST5, ST6, ST7, ST8);
  SIGNAL CURRENT_STATE, NEXT_STATE : STATE_TYPE;

BEGIN

  --STATE MACHINE LOGIC START----------------------

  --CURRENT STATE LOGIC
  SEQ : PROCESS (PXL_CLK, RST, NEXT_STATE)
  BEGIN

    IF (RST = '1') THEN
      CURRENT_STATE <= ST0;
    ELSIF RISING_EDGE(PXL_CLK) THEN
      CURRENT_STATE <= NEXT_STATE;
    END IF;

  END PROCESS;

  --NEXT STATE LOGIC

  COMB : PROCESS (CURRENT_STATE)
  BEGIN

    CASE CURRENT_STATE IS --DISPLAY MESSAGE//WELCOME/ASK FOR LIC
      WHEN ST0 =>       --DISPLAY MESSAGE
      IF(DECODE = "1010") THEN --A = NEXT PROMPT
      NEXT_STATE <= ST1;
      ELSIF(DECODE = "1100") THEN  --STAY IN WELCOME SCREEN
      NEXT_STATE <= ST0;
      ELSE
      NEXT_STATE <= ST0;
      END IF;
      
      WHEN ST1 => --USER IS REQUIRED TO ENTER AN INPUT, KEEP ASKING FOR AN INPUT
      IF(DECODE = "1010") THEN
      NEXT_STATE <= ST1; --NO, DONT PRESS A, KEEP ASKING FOR INPUT
      ELSIF(DECODE /= "1010" OR DECODE /= "1100") THEN
--      NUMBER_SAVE <= DECODE; --STORE THE NUMBER
      NEXT_STATE <= ST2; --NOW USER CAN EITHER PRESS A, C
      ELSE
      NEXT_STATE <= ST1;
      END IF;
      
      WHEN ST2 => --USER HAS ENTERED AN INPUT
      IF(DECODE = "1010") THEN --USER HAS PRESSED  A GO TO NEXT PROMT
      NEXT_STATE <= ST3;
      ELSIF (DECODE = "1100") THEN
      NEXT_STATE <= ST0;
      ELSE 
      NEXT_STATE <= ST2;
      END IF;
        
      --OPTIONS--  
      WHEN ST3 => --DISPLAY OPTIONS
      IF(DECODE = "1010") THEN --A NEXT PROMPT
      NEXT_STATE <= ST3;
      ELSIF (DECODE = "1100") THEN --C GO BACK TO WELCOME SCREEN
      NEXT_STATE <= ST0;
      ELSIF (DECODE = "0100" OR DECODE = "0101") THEN  --IF USER PRESSES 4 THEN GO TO ALL DAY PROMPT
      NEXT_STATE <= ST4;     
      ELSIF (DECODE = "0001" OR DECODE = "0010" OR DECODE = "0011") THEN --IF USER PRESSES 1,2,3 GO TO HOUR PROMT
      NUMBER_SAVE <= DECODE;
      NEXT_STATE <= ST6;
      ELSE 
      NEXT_STATE <= ST3;
      END IF;
      
      --ALL DAY PROMPT
      WHEN ST4 => 
      IF(DECODE /= "1100" OR DECODE /= "1010") THEN
      NUMBER_SAVE <= DECODE;
      END IF;
      IF(DECODE = "1100") THEN --USER PRESSED C, GO BACK TO WELCOME
      NEXT_STATE <= ST0;
      ELSE
      NEXT_STATE <= ST5; --KEEP ASKING FOR INPUT
      END IF;
--      END IF;
      
      WHEN ST5 => --USER HAS ENTERED INPUT OTHER THAN 1 DAYS (2,3,4,5,6,7,8,9)
      IF(DECODE /= "1010" OR DECODE /= "1100") THEN
      NUMBER_SAVE <= DECODE;
      END IF;
      IF(DECODE = "1010") THEN
      NEXT_STATE <= ST6; --A THEN ACCEPT INPUT AND NEXT PROMT
      ELSIF (DECODE = "1100") THEN --C THEN GO BACK TO WELCOME PAGE
      NEXT_STATE <= ST0;
      ELSE
      NEXT_STATE <= ST5; 
      END IF;
      
      --ENTER CARD--
      WHEN ST6 => 
      IF(DECODE = "1001") THEN --IF 9: PAYMENT ACCEPTED
      NEXT_STATE <= ST7; 
      ELSIF(DECODE = "1100") THEN
      NEXT_STATE <= ST8; -- C TRANSACTION CANCELLED
      ELSE
      NEXT_STATE <= ST6;
      END IF;
      
--      --ENTERING PIN
--      WHEN ST9 =>
--      IF(DECODE = "1010") THEN
--      NEXT_STATE <= ST7;
--      ELSE 
--      NEXT_STATE <= ST9;
--      END IF;
      
      --PAYMENT ACCEPTED
      WHEN ST7 => --INPUT 1{0} DAY
      NEXT_STATE <= ST7;
      
      --TRANSACTION CANCELLED
      WHEN ST8 => --AFTER ENTERING NUM OF DAYS
      NEXT_STATE <= ST8;
      

    END CASE;
  END PROCESS;
  

PROCESS(PXL_CLK) BEGIN

IF(RST = '1') THEN
TIMER <= 0;

ELSIF RISING_EDGE(PXL_CLK) THEN

IF(TIMER<990000000) THEN

TIMER <= TIMER + 1;

ELSE
TIMER <= 0; 
DIG_SEL <= not DIG_SEL;
END IF;

END IF;

END PROCESS;

  --STATE MACHINE LOGIC END------------------------------------
  
   blk_mem_inst1 : blk_mem_gen_0
  PORT MAP
  (
    clka => pxl_clk,
    douta => doutb,
    addra => addrb,
    ena => ena
  );

  blk_mem_inst : blk_mem_gen_0
  PORT MAP
  (
    clka => pxl_clk,
    douta => douta,
    addra => addra,
    ena => ena
  );

  DC0 : Decoder PORT MAP(
    clk => pxl_clk,
    rst => rst,
    Row => row,
    Col => col,
    DecodeOut => decode);

  clk_div_inst : clk_wiz_0
  PORT MAP
  (-- Clock in ports
    CLK_IN1 => CLK_I,
    -- Clock out ports
    CLK_OUT1 => pxl_clk);

  vga_red <= (OTHERS => img_pixel);
  vga_green <= (OTHERS => img_pixel);
  vga_blue <= (OTHERS => img_pixel);

  lower_bound <= 101;
  upper_bound <= 250;
  vert <= conv_integer(v_cntr_Reg(6 DOWNTO 2));
  horz <= conv_integer(h_cntr_Reg(6 DOWNTO 2));
  
  WITH (number_save) SELECT
  addrb <= STD_LOGIC_VECTOR(to_unsigned(a0, addrb'length)) WHEN "0000", --0
    STD_LOGIC_VECTOR(to_unsigned(a1, addrb'length)) WHEN "0001", --1 1 hour
    STD_LOGIC_VECTOR(to_unsigned(a2, addrb'length)) WHEN "0010", --2 2 hour
    STD_LOGIC_VECTOR(to_unsigned(a4, addrb'length)) WHEN "0011", --3 4 hour
    STD_LOGIC_VECTOR(to_unsigned(a4, addrb'length)) WHEN "0100",
    STD_LOGIC_VECTOR(to_unsigned(a5, addrb'length)) WHEN "0101",
    STD_LOGIC_VECTOR(to_unsigned(a6, addrb'length)) WHEN "0110",
    STD_LOGIC_VECTOR(to_unsigned(a7, addrb'length)) WHEN "0111",
    STD_LOGIC_VECTOR(to_unsigned(a8, addrb'length)) WHEN "1000",
    STD_LOGIC_VECTOR(to_unsigned(a9, addrb'length)) WHEN "1001",
    "0000100" WHEN OTHERS;

  --KEYPAD DIGITS
  WITH (decode) SELECT
  addra <= STD_LOGIC_VECTOR(to_unsigned(a0, addra'length)) WHEN "0000",
    STD_LOGIC_VECTOR(to_unsigned(a1, addra'length)) WHEN "0001",
    STD_LOGIC_VECTOR(to_unsigned(a2, addra'length)) WHEN "0010",
    STD_LOGIC_VECTOR(to_unsigned(a3, addra'length)) WHEN "0011",
    STD_LOGIC_VECTOR(to_unsigned(a4, addra'length)) WHEN "0100",
    STD_LOGIC_VECTOR(to_unsigned(a5, addra'length)) WHEN "0101",
    STD_LOGIC_VECTOR(to_unsigned(a6, addra'length)) WHEN "0110",
    STD_LOGIC_VECTOR(to_unsigned(a7, addra'length)) WHEN "0111",
    STD_LOGIC_VECTOR(to_unsigned(a8, addra'length)) WHEN "1000",
    STD_LOGIC_VECTOR(to_unsigned(a9, addra'length)) WHEN "1001",
    "0000100" WHEN OTHERS;
    
      img2(0) <= doutb(783 DOWNTO 756);
      img2(1) <= doutb(755 DOWNTO 728);
      img2(2) <= doutb(727 DOWNTO 700);
      img2(3) <= doutb(699 DOWNTO 672);
      img2(4) <= doutb(671 DOWNTO 644);
      img2(5) <= doutb(643 DOWNTO 616);
      img2(6) <= doutb(615 DOWNTO 588);
      img2(7) <= doutb(587 DOWNTO 560);
      img2(8) <= doutb(559 DOWNTO 532);
      img2(9) <= doutb(531 DOWNTO 504);
      img2(10) <= doutb(503 DOWNTO 476);
      img2(11) <= doutb(475 DOWNTO 448);
      img2(12) <= doutb(447 DOWNTO 420);
      img2(13) <= doutb(419 DOWNTO 392);
      img2(14) <= doutb(391 DOWNTO 364);
      img2(15) <= doutb(363 DOWNTO 336);
      img2(16) <= doutb(335 DOWNTO 308);
      img2(17) <= doutb(307 DOWNTO 280);
      img2(18) <= doutb(279 DOWNTO 252);
      img2(19) <= doutb(251 DOWNTO 224);
      img2(20) <= doutb(223 DOWNTO 196);
      img2(21) <= doutb(195 DOWNTO 168);
      img2(22) <= doutb(167 DOWNTO 140);
      img2(23) <= doutb(139 DOWNTO 112);
      img2(24) <= doutb(111 DOWNTO 84);
      img2(25) <= doutb(83 DOWNTO 56);
      img2(26) <= doutb(55 DOWNTO 28);
      img2(27) <= doutb(27 DOWNTO 0);


      img(0) <= douta(783 DOWNTO 756);
      img(1) <= douta(755 DOWNTO 728);
      img(2) <= douta(727 DOWNTO 700);
      img(3) <= douta(699 DOWNTO 672);
      img(4) <= douta(671 DOWNTO 644);
      img(5) <= douta(643 DOWNTO 616);
      img(6) <= douta(615 DOWNTO 588);
      img(7) <= douta(587 DOWNTO 560);
      img(8) <= douta(559 DOWNTO 532);
      img(9) <= douta(531 DOWNTO 504);
      img(10) <= douta(503 DOWNTO 476);
      img(11) <= douta(475 DOWNTO 448);
      img(12) <= douta(447 DOWNTO 420);
      img(13) <= douta(419 DOWNTO 392);
      img(14) <= douta(391 DOWNTO 364);
      img(15) <= douta(363 DOWNTO 336);
      img(16) <= douta(335 DOWNTO 308);
      img(17) <= douta(307 DOWNTO 280);
      img(18) <= douta(279 DOWNTO 252);
      img(19) <= douta(251 DOWNTO 224);
      img(20) <= douta(223 DOWNTO 196);
      img(21) <= douta(195 DOWNTO 168);
      img(22) <= douta(167 DOWNTO 140);
      img(23) <= douta(139 DOWNTO 112);
      img(24) <= douta(111 DOWNTO 84);
      img(25) <= douta(83 DOWNTO 56);
      img(26) <= douta(55 DOWNTO 28);
      img(27) <= douta(27 DOWNTO 0);

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF (update_box = '1') THEN
        IF (box_x_dir = '1') THEN
          box_x_reg <= box_x_reg + 1;
        ELSE
          box_x_reg <= box_x_reg - 1;
        END IF;
        IF (box_y_dir = '1') THEN
          box_y_reg <= box_y_reg + 1;
        ELSE
          box_y_reg <= box_y_reg - 1;
        END IF;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF (update_box = '1') THEN
        IF ((box_x_dir = '1' AND (box_x_reg = BOX_X_MAX - 1)) OR (box_x_dir = '0' AND (box_x_reg = BOX_X_MIN + 1))) THEN
          box_x_dir <= NOT(box_x_dir);
        END IF;
        IF ((box_y_dir = '1' AND (box_y_reg = BOX_Y_MAX - 1)) OR (box_y_dir = '0' AND (box_y_reg = BOX_Y_MIN + 1))) THEN
          box_y_dir <= NOT(box_y_dir);
        END IF;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF (box_cntr_reg = (BOX_CLK_DIV - 1)) THEN
        box_cntr_reg <= (OTHERS => '0');
        vert_count <= vert_count + 1;
        horz_count <= horz_count + 1;
      ELSE
        box_cntr_reg <= box_cntr_reg + 1;
        horz_count <= (OTHERS => '0');
        vert_count <= (OTHERS => '0');
      END IF;
    END IF;
  END PROCESS;

  update_box <= '1' WHEN box_cntr_reg = (BOX_CLK_DIV - 1) ELSE
    '0';


process(PXL_CLK, RST)
begin

if(rst = '1') then

img_pixel <= '0';

elsif rising_edge(PXL_CLK) then
--welcome
if((h_cntr_reg >= 0 AND (h_cntr_reg < 900) AND v_cntr_reg >= 390 AND (v_cntr_reg < 500)) and CURRENT_STATE=ST0 AND TIMER >= 0 AND DIG_SEL = '0') then
img_pixel <= WELCOME(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));

--lic
elsif (h_cntr_reg >= 0 AND (h_cntr_reg < 800) AND v_cntr_reg >= 390 AND (v_cntr_reg < 500)) and ((CURRENT_STATE=ST0  AND TIMER > 920000 AND DIG_SEL = '1') 
OR CURRENT_STATE = ST1 OR CURRENT_STATE = ST2) then

img_pixel <= ENTER_LIC(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));

--promt
elsif ((h_cntr_reg >= 500 AND (h_cntr_reg < 649) AND v_cntr_reg >= 101 AND (v_cntr_reg < 250)) 
 AND (douta > 0))then
 
img_pixel <= img(vert)(horz);

--options
elsif (h_cntr_reg >= 0 AND (h_cntr_reg < 800) AND v_cntr_reg >= 0 AND (v_cntr_reg < 600)) and CURRENT_STATE=ST3
then 

img_pixel <= OPTION(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));

--days option// 380 370
elsif (h_cntr_reg >= 0 AND (h_cntr_reg < 380) AND v_cntr_reg >= 200 AND (v_cntr_reg < 370)) and 
 (CURRENT_STATE = ST4 or CURRENT_STATE = ST5) then 
 
 img_pixel <= DAYS_PIXEL(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));

elsif (h_cntr_reg >= 0 AND (h_cntr_reg < 380) AND v_cntr_reg >= 500 AND (v_cntr_reg < 810)) and 
 CURRENT_STATE = ST6 then --payment accepted
 
 img_pixel <= INSERT_CARD(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));


elsif (h_cntr_reg >= 0 AND (h_cntr_reg < 490) AND v_cntr_reg >= 210 AND (v_cntr_reg < 500)) and 
 CURRENT_STATE = ST7 then  --PAYMENT ACCEPTED
 
 img_pixel <= PAYMENT_ACC(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));
 
--PAYMENT AMOUNT
elsif ((h_cntr_reg >= 500 AND (h_cntr_reg < 649) AND v_cntr_reg >= 500 AND (v_cntr_reg < 649)) 
 AND (douta > 0)) and CURRENT_STATE = ST7 then
 
img_pixel <= img2(vert)(horz);

elsif (h_cntr_reg >= 0 AND (h_cntr_reg < 600) AND v_cntr_reg >= 260 AND (v_cntr_reg < 500)) and 
 CURRENT_STATE = ST8 then  --TRANSAC CANCELLED
 
 img_pixel <= TRANSAC(conv_integer(v_cntr_reg(10 downto 3)))((conv_integer(h_cntr_reg(10 downto 3))));
 
else

img_pixel <= '0';

end if;

end if;


end process;


  ------------------------------------------------------
  -------         SYNC GENERATION                 ------
  ------------------------------------------------------

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF (h_cntr_reg = (H_MAX - 1)) THEN
        h_cntr_reg <= (OTHERS => '0');
      ELSE
        h_cntr_reg <= h_cntr_reg + 1;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF ((h_cntr_reg = (H_MAX - 1)) AND (v_cntr_reg = (V_MAX - 1))) THEN
        v_cntr_reg <= (OTHERS => '0');
        v_cntr_reg <= (OTHERS => '0');
      ELSIF (h_cntr_reg = (H_MAX - 1)) THEN
        v_cntr_reg <= v_cntr_reg + 1;
      END IF;
    END IF;
  END PROCESS;

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) AND (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) THEN
        h_sync_reg <= H_POL;
      ELSE
        h_sync_reg <= NOT(H_POL);
      END IF;
    END IF;
  END PROCESS;
  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      IF (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) AND (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) THEN
        v_sync_reg <= V_POL;
      ELSE
        v_sync_reg <= NOT(V_POL);
      END IF;
    END IF;
  END PROCESS;
  active <= '1' WHEN ((h_cntr_reg < FRAME_WIDTH) AND (v_cntr_reg < FRAME_HEIGHT))ELSE
    '0';

  PROCESS (pxl_clk)
  BEGIN
    IF (rising_edge(pxl_clk)) THEN
      v_sync_dly_reg <= v_sync_reg;
      h_sync_dly_reg <= h_sync_reg;
      vga_red_reg <= vga_red;
      vga_green_reg <= vga_green;
      vga_blue_reg <= vga_blue;
    END IF;
  END PROCESS;

  VGA_HS_O <= h_sync_dly_reg;
  VGA_VS_O <= v_sync_dly_reg;
  VGA_R <= vga_red_reg;
  VGA_G <= vga_green_reg;
  VGA_B <= vga_blue_reg;
END Behavioral;