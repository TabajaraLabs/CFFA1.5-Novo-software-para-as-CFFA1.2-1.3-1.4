`timescale 1ns/1ps
module tb;
  reg A0,A1,A2,A3,A8,A9,A10,RW,nDEVSEL,nIOSEL,nIOSTRB,CLK7M=0;
  wire [13:0] r,d; wire nWE; wire BK13,BK14;
  ref14 R(A0,A1,A2,A3,A8,A9,A10,RW,nDEVSEL,nIOSEL,nIOSTRB,CLK7M, r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],r[10],r[11],r[12],r[13]);
  cffa_core_v16 D(.A0(A0),.A1(A1),.A2(A2),.A3(A3),.A8(A8),.A9(A9),.A10(A10),.RW(RW),.nDEVSEL(nDEVSEL),.nIOSEL(nIOSEL),.nIOSTRB(nIOSTRB),.CLK7M(CLK7M),
   .nR_HOST(d[0]),.R_ATA(d[1]),.W_HOST(d[2]),.nW_ATA(d[3]),.nIOWR(d[4]),.nIORD(d[5]),.nCS0(d[6]),.nCS1(d[7]),.nDBUS245(d[8]),.nEPROM_EN(d[9]),.NOT_RW(d[10]),.LA0(d[11]),.LA1(d[12]),.LA2(d[13]),.nWE(nWE),.BK13(BK13),.BK14(BK14));
  pullup(BK13); pullup(BK14);
  initial begin #0.5; forever #70 CLK7M=~CLK7M; end
  integer i, err=0, wes=0;
  initial begin
    {A0,A1,A2,A3,A8,A9,A10,RW,nDEVSEL,nIOSEL,nIOSTRB}=11'h7ff;
    for(i=0;i<200000;i=i+1) begin
      #(17+($random&63));
      {A0,A1,A2,A3,A8,A9,A10,RW} = $random;
      nDEVSEL = ($random%4)!=0; nIOSEL=($random%4)!=0; nIOSTRB=($random%4)!=0;
      #3; if(r!==d) begin err=err+1; if(err<4) $display("DIF t=%0t ref=%b dut=%b cs %b %b c8 %b %b la3 %b %b dsel %b %b la %b%b%b %b%b%b",$time,r,d,R.cs,D.cs_mask,R.lc48,D.nC800_FF,R.ioc18,D.la3,R.ioc6,D.dsel1,R.la2,R.la1,R.la0,D.la2,D.la1,D.la0); end
      if(nWE===0) wes=wes+1;
    end
    $display("comparacoes=%0d erros=%0d  (nWE baixo %0d vezes com we_en aleatorio)",i,err,wes);
    $finish;
  end
endmodule
