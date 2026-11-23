// cffa_core_v15.v - Logica do CPLD da CFFA (Rich Dreher) e da CFFA Lite (Tabajara Labs), nucleo comum
// Versao 1.5 (2026-11-20) para Quartus II 13.0sp1, EPM7064SLC44-10.
//
// Base: appleidelogic.tdf v1.4 (Rich Dreher, abr/2005), reproduzida equacao por equacao a partir
// do relatorio de compilacao (appleideinterface.rpt). Comportamento da v1.4 inalterado.
//
// Novidades da v1.5 (so usa os pinos livres 8, 24 e 27; CS_MASK virou no interno):
//  * /WE para EEPROM 28C256 (pino 8), com trava por software:
//      escrita em $C0n3 -> destrava ; leitura em $C0n3 -> trava (estado inicial: travada)
//    O pulso /WE e sincronizado ao 7M: comeca ~1 periodo depois do inicio do acesso a ROM e
//    dura 2 periodos (~280 ns), terminando antes do fim do /IOSTROBE ou /IOSELECT, quando o
//    dado do 65C02 ainda esta estavel. Nunca escreve na faixa $CFxx.
//  * Banco da ROM por software (saidas em dreno aberto, o pull-up de 10k da placa da o "1";
//    um jumper fechado no JP2 continua forcando "0" sem conflito):
//      $C0n4: escrita -> A13=1 ; leitura -> A13=0   (pino 24)
//      $C0n5: escrita -> A14=1 ; leitura -> A14=0   (pino 27)
//    Estado inicial (power-up): A13=A14=0 = banco do jumper do A12.
//    Obs.: Ctrl-Reset nao zera estes bits (o CPLD nao recebe /RESET); o firmware de cada
//    banco deve gravar o banco padrao logo no inicio.
// Em instrucoes STA abs,X do 6502 ha uma leitura falsa antes da escrita: vale o ultimo acesso.

module cffa_core_v15 (
    input  wire A0, A1, A2, A3, A8, A9, A10,
    input  wire RW,          // R/W do Apple (1 = leitura)
    input  wire nDEVSEL,     // /DEVICE SELECT
    input  wire nIOSEL,      // /IO SELECT
    input  wire nIOSTRB,     // /IO STROBE
    input  wire CLK7M,       // 7M
    output wire nR_HOST, R_ATA, W_HOST, nW_ATA,
    output wire nIOWR, nIORD, nCS0, nCS1,
    output wire nDBUS245, nEPROM_EN, NOT_RW,
    output wire LA0, LA1, LA2,
    output wire nWE,         // NOVO: /WE da EEPROM        (pino 8)
    inout  wire BK13,        // NOVO: A13 da ROM, dreno aberto (pino 24)
    inout  wire BK14         // NOVO: A14 da ROM, dreno aberto (pino 27)
);
    // ---------------- v1.4 ----------------
    reg la0=0, la1=0, la2=0, la3=0;
    always @(posedge CLK7M) if (nDEVSEL) begin la0<=A0; la1<=A1; la2<=A2; la3<=A3; end
    assign LA0=la0; assign LA1=la1; assign LA2=la2;

    wire nCFXX = ~(A8 & A9 & A10 & ~nIOSTRB);

    // /C800_FF = SRFF(S = !/CFXX, R = !/IO_SEL) ; 1 = ROM de expansao desligada
    reg nC800_FF = 0;
    always @(posedge CLK7M)
        if (~nCFXX & nIOSEL)      nC800_FF <= 1'b1;
        else if (nCFXX & ~nIOSEL) nC800_FF <= 1'b0;
        else if (~nCFXX & ~nIOSEL) nC800_FF <= ~nC800_FF;   // SRFF S=R=1: alterna (igual ao TFFE do .rpt)

    assign NOT_RW = ~RW;
    assign nEPROM_EN = (nC800_FF | nIOSTRB) ~^ nIOSEL;

    // mascara de CS0 (truque SanDisk): leitura em $C0n1 liga, $C0n2 desliga
    wire set_mask   = ~nDEVSEL & ~la3 & ~la2 & ~la1 &  la0;
    wire reset_mask = ~nDEVSEL & ~la3 & ~la2 &  la1 & ~la0;
    reg cs_mask = 0;
    always @(posedge CLK7M)
        if (set_mask & ~reset_mask) cs_mask <= 1'b1;
        else if (reset_mask & ~set_mask) cs_mask <= 1'b0;

    reg dsel1 = 1, dsel2 = 1;
    always @(negedge CLK7M) begin dsel1 <= nDEVSEL; dsel2 <= dsel1; end

    wire anyLA = la3 | la2 | la1 | la0;
    assign nIOWR = nDEVSEL | dsel2 | RW  | ~anyLA;
    assign nIORD = nDEVSEL | dsel1 | ~RW | ~anyLA;
    assign nR_HOST = nDEVSEL | anyLA | ~RW;
    assign R_ATA   = ~nDEVSEL & ~dsel1 &  la3 & ~la2 & ~la1 & ~la0 & RW;
    assign W_HOST  = ~nDEVSEL & ~dsel1 & ~anyLA & ~RW;
    assign nW_ATA  = dsel1 | ~la3 | la2 | la1 | la0 | RW;
    assign nCS0    = (nDEVSEL & dsel1) | ~la3 | (cs_mask & RW);
    assign nCS1    = (nDEVSEL & dsel1) | la3 | ~(la1 & la2) | (cs_mask & RW);
    assign nDBUS245 = nDEVSEL & nEPROM_EN & nIOSEL;

    // ---------------- v1.5: registradores por endereco ($C0n3, $C0n4, $C0n5) ----------------
    // decodifica com o endereco travado (LA) no fim do ciclo do DEVSEL (borda de subida do 7M com DEVSEL ativo)
    wire acc3 = ~nDEVSEL & ~la3 & ~la2 &  la1 &  la0;
    wire acc4 = ~nDEVSEL & ~la3 &  la2 & ~la1 & ~la0;
    wire acc5 = ~nDEVSEL & ~la3 &  la2 & ~la1 &  la0;
    reg we_en = 0, bk13 = 0, bk14 = 0;
    always @(posedge CLK7M) begin
        if (acc3) we_en <= ~RW;
        if (acc4) bk13  <= ~RW;
        if (acc5) bk14  <= ~RW;
    end
    assign BK13 = bk13 ? 1'bz : 1'b0;
    assign BK14 = bk14 ? 1'bz : 1'b0;

    // ---------------- v1.5: /WE da EEPROM ----------------
    // escrita na ROM da placa ($Cn00-$CnFF ou $C800-$CEFF), destravada, fora de $CFxx
    wire romwr = we_en & ~RW & ~nEPROM_EN & nCFXX;
    reg w1 = 0, w2 = 0, w3 = 0;
    always @(posedge CLK7M) begin
        w1 <= romwr;
        w2 <= w1 & romwr;
        w3 <= w2 & romwr;
    end
    assign nWE = ~(w1 & ~w3 & romwr);
endmodule
