// Referencia: equacoes do appleideinterface.rpt (MAX+plus II, logica 1.4) transcritas literalmente
module ref14(input A0,A1,A2,A3,A8,A9,A10,RW,nDEVSEL,nIOSEL,nIOSTRB,CLK7M,
  output nR_HOST,R_ATA,W_HOST,nW_ATA,nIOWR,nIORD,nCS0,nCS1,nDBUS245,nEPROM_EN,NOT_RW,LA0,LA1,LA2);
  reg ioc18=0, la0=0,la1=0,la2=0, cs=0, lc48=0, lc58=1, ioc6=1;
  always @(posedge CLK7M) begin
    if(nDEVSEL) begin ioc18<=A3; la0<=A0; la1<=A1; la2<=A2; end
    if( (cs & ~nDEVSEL & ~ioc18 & ~la0 & la1 & ~la2) | (~cs & ~nDEVSEL & ~ioc18 & la0 & ~la1 & ~la2) ) cs<=~cs;
    if( (A8&A9&A10&~nIOSTRB&~lc48) | (~nIOSEL & lc48) ) lc48<=~lc48;
  end
  always @(negedge CLK7M) begin ioc6<=nDEVSEL; lc58<=ioc6; end
  assign LA0=la0; assign LA1=la1; assign LA2=la2;
  assign nDBUS245 = (nDEVSEL & nIOSEL & lc48) | (nDEVSEL & nIOSEL & nIOSTRB);
  assign NOT_RW = ~RW;
  assign R_ATA = ~nDEVSEL & ~ioc6 & ioc18 & ~la0 & ~la1 & ~la2 & RW;
  assign W_HOST = ~nDEVSEL & ~ioc6 & ~ioc18 & ~la0 & ~la1 & ~la2 & ~RW;
  assign nCS0 = (cs & RW) | (nDEVSEL & ioc6) | ~ioc18;
  assign nCS1 = ~( (~ioc6 & ~ioc18 & la1 & la2 & ~RW) | (~cs & ~ioc6 & ~ioc18 & la1 & la2) | (~nDEVSEL & ~ioc18 & la1 & la2 & ~RW) | (~cs & ~nDEVSEL & ~ioc18 & la1 & la2) );
  assign nEPROM_EN = (~nIOSTRB & ~lc48) ^ nIOSEL;
  assign nIORD = (~ioc18 & ~la0 & ~la1 & ~la2) | ioc6 | nDEVSEL | ~RW;
  assign nIOWR = (~ioc18 & ~la0 & ~la1 & ~la2) | RW | lc58 | nDEVSEL;
  assign nR_HOST = ~(~nDEVSEL & ~ioc18 & ~la0 & ~la1 & ~la2 & RW);
  assign nW_ATA = ~(~ioc6 & ioc18 & ~la0 & ~la1 & ~la2 & ~RW);
endmodule
