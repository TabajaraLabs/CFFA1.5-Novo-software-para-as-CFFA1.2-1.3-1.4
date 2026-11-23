`timescale 1ns/1ps
// Teste dirigido das funcoes novas (v1.5), com temporizacao aproximada do barramento do Apple IIe
module tb2;
  reg [15:0] addr; reg RW=1, nDEVSEL=1, nIOSEL=1, nIOSTRB=1, CLK7M=0;
  wire [13:0] d; wire nWE; wire BK13,BK14; pullup(BK13); pullup(BK14);
  cffa_core_v15 D(.A0(addr[0]),.A1(addr[1]),.A2(addr[2]),.A3(addr[3]),.A8(addr[8]),.A9(addr[9]),.A10(addr[10]),.RW(RW),
   .nDEVSEL(nDEVSEL),.nIOSEL(nIOSEL),.nIOSTRB(nIOSTRB),.CLK7M(CLK7M),
   .nR_HOST(d[0]),.R_ATA(d[1]),.W_HOST(d[2]),.nW_ATA(d[3]),.nIOWR(d[4]),.nIORD(d[5]),.nCS0(d[6]),.nCS1(d[7]),.nDBUS245(d[8]),.nEPROM_EN(d[9]),.NOT_RW(d[10]),.LA0(d[11]),.LA1(d[12]),.LA2(d[13]),.nWE(nWE),.BK13(BK13),.BK14(BK14));
  initial begin #0.5; forever #69.8 CLK7M=~CLK7M; end
  real tfall, wmin=1e9, wmax=0; integer npulse=0;
  always @(negedge nWE) tfall=$realtime;
  always @(posedge nWE) if(tfall>0) begin npulse=npulse+1; if($realtime-tfall<wmin) wmin=$realtime-tfall; if($realtime-tfall>wmax) wmax=$realtime-tfall; end
  // um ciclo de barramento de 978 ns: PH1 489 ns (endereco/RW mudam), PH0 489 ns (selects ativos)
  task ciclo(input [15:0] a, input r); begin
    addr=a; RW=r; #489;
    if(a[15:4]==12'hC07) nDEVSEL=0;           // slot 7: $C0F0-$C0FF -> a[7:4]=F; simplificado abaixo
    if(a[15:8]==8'hC7) nIOSEL=0;
    if(a>=16'hC800 && a<=16'hCFFF) nIOSTRB=0;
    if(a[15:4]==12'hC0F) nDEVSEL=0;
    #489; nDEVSEL=1; nIOSEL=1; nIOSTRB=1;
  end endtask
  integer n0;
  initial begin
    addr=0; #1000;
    ciclo(16'hC700,1);                         // liga a ROM de expansao (C800) da placa
    n0=npulse; ciclo(16'hC800,0);              // escrita com trava (estado inicial) -> nao pode gravar
    $display("escrita travada:   pulsos /WE = %0d (esperado 0)", npulse-n0);
    ciclo(16'hC0F3,0);                         // destrava
    n0=npulse; ciclo(16'hC812,0); ciclo(16'hC700,0);
    $display("escrita destravada em $C812 e $C700: pulsos = %0d (esperado 2), largura %0.0f-%0.0f ns", npulse-n0, wmin, wmax);
    n0=npulse; ciclo(16'hCFFF,0);
    $display("escrita em $CFFF:  pulsos = %0d (esperado 0)", npulse-n0);
    ciclo(16'hC700,1);
    n0=npulse; ciclo(16'hC0F3,1); ciclo(16'hC820,0);
    $display("depois de ler $C0F3 (trava): pulsos = %0d (esperado 0)", npulse-n0);
    $display("BK14 inicial = %b (esperado 0)", BK14);
    ciclo(16'hC0F5,0); #10 $display("escrita $C0F5 -> BK14 = %b (esperado 1)", BK14);
    ciclo(16'hC0F5,1); #10 $display("leitura $C0F5 -> BK14 = %b (esperado 0)", BK14);
    ciclo(16'hC0F4,0); #10 $display("escrita $C0F4 -> BK13 = %b (esperado 1)", BK13);
    $finish;
  end
endmodule
