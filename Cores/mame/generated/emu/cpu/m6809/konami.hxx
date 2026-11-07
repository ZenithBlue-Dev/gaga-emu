	case 0:	goto MAIN;
	case 1:	goto INTERRUPT_VECTOR;
	case 2:	goto state_2;
	case 3:	goto LEA_xy;
	case 4:	goto LEA_us;
	case 5:	goto LD8;
	case 6:	goto ADD8;
	case 7:	goto ADC8;
	case 8:	goto SUB8;
	case 9:	goto SBC8;
	case 10:	goto AND8;
	case 11:	goto BIT8;
	case 12:	goto EOR8;
	case 13:	goto OR8;
	case 14:	goto CMP8;
	case 15:	goto SETLN;
	case 16:	goto ST8;
	case 17:	goto LD16;
	case 18:	goto CMP16;
	case 19:	goto ADD16;
	case 20:	goto SUB16;
	case 21:	goto ST16;
	case 22:	goto CLR8;
	case 23:	goto COM8;
	case 24:	goto NEG8;
	case 25:	goto INC8;
	case 26:	goto DEC8;
	case 27:	goto TST8;
	case 28:	goto LSR8;
	case 29:	goto ROR8;
	case 30:	goto ASR8;
	case 31:	goto ASL8;
	case 32:	goto ROL8;
	case 33:	goto LSR16;
	case 34:	goto ROR16;
	case 35:	goto ASR16;
	case 36:	goto ASL16;
	case 37:	goto ROL16;
	case 38:	goto JMP;
	case 39:	goto JSR;
	case 40:	goto state_40;
	case 41:	goto LSRDI;
	case 42:	goto state_42;
	case 43:	goto RORDI;
	case 44:	goto state_44;
	case 45:	goto ASRDI;
	case 46:	goto state_46;
	case 47:	goto ASLDI;
	case 48:	goto state_48;
	case 49:	goto ROLDI;
	case 50:	goto CLR16;
	case 51:	goto NEG16;
	case 52:	goto INC16;
	case 53:	goto DEC16;
	case 54:	goto TST16;
	case 55:	goto state_55;
	case 56:	goto state_56;
	case 57:	goto state_57;
	case 58:	goto state_58;
	case 59:	goto state_59;
	case 60:	goto state_60;
	case 61:	goto state_61;
	case 62:	goto state_62;
	case 63:	goto state_63;
	case 64:	goto state_64;
	case 65:	goto state_65;
	case 66:	goto state_66;
	case 67:	goto state_67;
	case 68:	goto state_68;
	case 69:	goto state_69;
	case 70:	goto state_70;
	case 71:	goto state_71;
	case 72:	goto state_72;
	case 73:	goto state_73;
	case 74:	goto state_74;
	case 75:	goto state_75;
	case 76:	goto state_76;
	case 77:	goto state_77;
	case 78:	goto state_78;
	case 79:	goto state_79;
	case 80:	goto state_80;
	case 81:	goto state_81;
	case 82:	goto state_82;
	case 83:	goto state_83;
	case 84:	goto state_84;
	case 85:	goto state_85;
	case 86:	goto state_86;
	case 87:	goto state_87;
	case 88:	goto state_88;
	case 89:	goto state_89;
	case 90:	goto state_90;
	case 91:	goto state_91;
	case 92:	goto state_92;
	case 93:	goto state_93;
	case 94:	goto state_94;
	case 95:	goto state_95;
	case 96:	goto state_96;
	case 97:	goto state_97;
	case 98:	goto state_98;
	case 99:	goto state_99;
	case 100:	goto state_100;
	case 101:	goto state_101;
	case 102:	goto state_102;
	case 103:	goto state_103;
	case 104:	goto state_104;
	case 105:	goto state_105;
	case 106:	goto state_106;
	case 107:	goto state_107;
	case 108:	goto state_108;
	case 109:	goto state_109;
	case 110:	goto state_110;
	case 111:	goto state_111;
	case 112:	goto state_112;
	case 113:	goto state_113;
	case 114:	goto state_114;
	case 115:	goto state_115;
	case 116:	goto state_116;
	case 117:	goto state_117;
	case 118:	goto state_118;
	case 119:	goto state_119;
	case 120:	goto state_120;
	case 121:	goto state_121;
	case 122:	goto state_122;
	case 123:	goto state_123;
	case 124:	goto state_124;
	case 125:	goto state_125;
	case 126:	goto state_126;
	case 127:	goto state_127;
	case 128:	goto state_128;
	case 129:	goto state_129;
	case 130:	goto state_130;
	case 131:	goto state_131;
	case 132:	goto state_132;
	case 133:	goto state_133;
	case 134:	goto state_134;
	case 135:	goto state_135;
	case 136:	goto state_136;
	case 137:	goto state_137;
	case 138:	goto state_138;
	case 139:	goto state_139;
	case 140:	goto state_140;
	case 141:	goto state_141;
	case 142:	goto state_142;
	case 143:	goto state_143;
	case 144:	goto state_144;
	case 145:	goto state_145;
	case 146:	goto state_146;
	case 147:	goto state_147;
	case 148:	goto state_148;
	case 149:	goto state_149;
	case 150:	goto state_150;
	case 151:	goto state_151;
	case 152:	goto state_152;
	case 153:	goto state_153;
	case 154:	goto state_154;
	case 155:	goto state_155;
	case 156:	goto state_156;
	case 157:	goto state_157;
	case 158:	goto state_158;
	case 159:	goto state_159;
	case 160:	goto state_160;
	case 161:	goto state_161;
	case 162:	goto state_162;
	case 163:	goto state_163;
	case 164:	goto state_164;
	case 165:	goto state_165;
	case 166:	goto state_166;
	case 167:	goto state_167;
	case 168:	goto state_168;
	case 169:	goto state_169;
	case 170:	goto state_170;
	case 171:	goto state_171;
	case 172:	goto state_172;
	case 173:	goto state_173;
	case 174:	goto state_174;
	case 175:	goto state_175;
	case 176:	goto state_176;
	case 177:	goto state_177;
	case 178:	goto state_178;
	case 179:	goto state_179;
	case 180:	goto state_180;
	case 181:	goto state_181;
	case 182:	goto state_182;
	case 183:	goto state_183;
	case 184:	goto state_184;
	case 185:	goto state_185;
	case 186:	goto state_186;
	case 187:	goto state_187;
	case 188:	goto state_188;
	case 189:	goto state_189;
	case 190:	goto state_190;
	case 191:	goto state_191;
	case 192:	goto state_192;
	case 193:	goto state_193;
	case 194:	goto state_194;
	case 195:	goto state_195;
	case 196:	goto state_196;
	case 197:	goto state_197;
	case 198:	goto state_198;
	case 199:	goto state_199;
	case 200:	goto state_200;
	case 201:	goto state_201;
	case 202:	goto state_202;
	case 203:	goto state_203;
	case 204:	goto state_204;
	case 205:	goto state_205;
	case 206:	goto state_206;
	case 207:	goto state_207;
	case 208:	goto state_208;
	case 209:	goto state_209;
	case 210:	goto state_210;
	case 211:	goto state_211;
	case 212:	goto state_212;
	case 213:	goto state_213;
	case 214:	goto state_214;
	case 215:	goto state_215;
	case 216:	goto state_216;
	case 217:	goto state_217;
	case 218:	goto state_218;
	case 219:	goto state_219;
	case 220:	goto state_220;
	case 221:	goto state_221;
	case 222:	goto state_222;
	case 223:	goto state_223;
	case 224:	goto state_224;
	case 225:	goto state_225;
	case 226:	goto state_226;
	case 227:	goto state_227;
	case 228:	goto state_228;
	case 229:	goto state_229;
	case 230:	goto state_230;
	case 231:	goto state_231;
	case 232:	goto state_232;
	case 233:	goto state_233;
	case 234:	goto state_234;
	case 235:	goto state_235;
	case 236:	goto state_236;
	case 237:	goto state_237;
	case 238:	goto state_238;
	case 239:	goto state_239;
	case 240:	goto state_240;
	case 241:	goto state_241;
	case 242:	goto state_242;
	case 243:	goto state_243;
	case 244:	goto state_244;
	case 245:	goto state_245;
	case 246:	goto state_246;
	case 247:	goto state_247;
	case 248:	goto state_248;
	case 249:	goto state_249;
	case 250:	goto state_250;
	case 251:	goto state_251;
	case 252:	goto state_252;
	case 253:	goto state_253;
	default:
		fatalerror("Unexpected state");
		break;

// license:BSD-3-Clause
// copyright-holders:Nathan Woods
MAIN:
	// check interrupt lines
	switch(get_pending_interrupt())
	{
		case VECTOR_NMI:    goto NMI;
		case VECTOR_FIRQ:   goto FIRQ;
		case VECTOR_IRQ:    goto IRQ;
	}

	// debugger hook
	m_ppc = m_pc;
	debugger_instruction_hook(m_pc.w);

	// opcode fetch
	m_opcode = read_opcode();
	if (UNEXPECTED(m_icount <= 0)) { push_state(2); return; }
state_2:

	// dispatch opcode
	switch(m_opcode)
	{
		case 0x08:              set_regop16(m_x);       push_state(3);	// LEA_xy
goto INDEXED;
		case 0x09:              set_regop16(m_y);       push_state(3);	// LEA_xy
goto INDEXED;
		case 0x0A:              set_regop16(m_u);       push_state(4);	// LEA_us
goto INDEXED;
		case 0x0B:              set_regop16(m_s);       push_state(4);	// LEA_us
goto INDEXED;
		case 0x0C:
			goto PSHS;
		case 0x0D:
			goto PSHU;
		case 0x0E:
			goto PULS;
		case 0x0F:
			goto PULU;

		case 0x10:              set_regop8(m_q.r.a);    set_imm();  goto LD8;
		case 0x11:              set_regop8(m_q.r.b);    set_imm();  goto LD8;
		case 0x12:              set_regop8(m_q.r.a);    push_state(5);	// LD8
goto INDEXED;
		case 0x13:              set_regop8(m_q.r.b);    push_state(5);	// LD8
goto INDEXED;
		case 0x14:              set_regop8(m_q.r.a);    set_imm();  goto ADD8;
		case 0x15:              set_regop8(m_q.r.b);    set_imm();  goto ADD8;
		case 0x16:              set_regop8(m_q.r.a);    push_state(6);	// ADD8
goto INDEXED;
		case 0x17:              set_regop8(m_q.r.b);    push_state(6);	// ADD8
goto INDEXED;
		case 0x18:              set_regop8(m_q.r.a);    set_imm();  goto ADC8;
		case 0x19:              set_regop8(m_q.r.b);    set_imm();  goto ADC8;
		case 0x1A:              set_regop8(m_q.r.a);    push_state(7);	// ADC8
goto INDEXED;
		case 0x1B:              set_regop8(m_q.r.b);    push_state(7);	// ADC8
goto INDEXED;
		case 0x1C:              set_regop8(m_q.r.a);    set_imm();  goto SUB8;
		case 0x1D:              set_regop8(m_q.r.b);    set_imm();  goto SUB8;
		case 0x1E:              set_regop8(m_q.r.a);    push_state(8);	// SUB8
goto INDEXED;
		case 0x1F:              set_regop8(m_q.r.b);    push_state(8);	// SUB8
goto INDEXED;

		case 0x20:              set_regop8(m_q.r.a);    set_imm();  goto SBC8;
		case 0x21:              set_regop8(m_q.r.b);    set_imm();  goto SBC8;
		case 0x22:              set_regop8(m_q.r.a);    push_state(9);	// SBC8
goto INDEXED;
		case 0x23:              set_regop8(m_q.r.b);    push_state(9);	// SBC8
goto INDEXED;
		case 0x24:              set_regop8(m_q.r.a);    set_imm();  goto AND8;
		case 0x25:              set_regop8(m_q.r.b);    set_imm();  goto AND8;
		case 0x26:              set_regop8(m_q.r.a);    push_state(10);	// AND8
goto INDEXED;
		case 0x27:              set_regop8(m_q.r.b);    push_state(10);	// AND8
goto INDEXED;
		case 0x28:              set_regop8(m_q.r.a);    set_imm();  goto BIT8;
		case 0x29:              set_regop8(m_q.r.b);    set_imm();  goto BIT8;
		case 0x2A:              set_regop8(m_q.r.a);    push_state(11);	// BIT8
goto INDEXED;
		case 0x2B:              set_regop8(m_q.r.b);    push_state(11);	// BIT8
goto INDEXED;
		case 0x2C:              set_regop8(m_q.r.a);    set_imm();  goto EOR8;
		case 0x2D:              set_regop8(m_q.r.b);    set_imm();  goto EOR8;
		case 0x2E:              set_regop8(m_q.r.a);    push_state(12);	// EOR8
goto INDEXED;
		case 0x2F:              set_regop8(m_q.r.b);    push_state(12);	// EOR8
goto INDEXED;

		case 0x30:              set_regop8(m_q.r.a);    set_imm();  goto OR8;
		case 0x31:              set_regop8(m_q.r.b);    set_imm();  goto OR8;
		case 0x32:              set_regop8(m_q.r.a);    push_state(13);	// OR8
goto INDEXED;
		case 0x33:              set_regop8(m_q.r.b);    push_state(13);	// OR8
goto INDEXED;
		case 0x34:              set_regop8(m_q.r.a);    set_imm();  goto CMP8;
		case 0x35:              set_regop8(m_q.r.b);    set_imm();  goto CMP8;
		case 0x36:              set_regop8(m_q.r.a);    push_state(14);	// CMP8
goto INDEXED;
		case 0x37:              set_regop8(m_q.r.b);    push_state(14);	// CMP8
goto INDEXED;
		case 0x38:                                      set_imm();  goto SETLN;
		case 0x39:
			push_state(15);	// SETLN
			goto INDEXED;
		case 0x3A:              set_regop8(m_q.r.a);    push_state(16);	// ST8
goto INDEXED;
		case 0x3B:              set_regop8(m_q.r.b);    push_state(16);	// ST8
goto INDEXED;
		case 0x3C:                                      set_imm();  goto ANDCC;
		case 0x3D:                                      set_imm();  goto ORCC;
		case 0x3E:  case 0x3F:
			goto EXGTFR;

		case 0x40:              set_regop16(m_q.p.d);   set_imm();  goto LD16;
		case 0x41:              set_regop16(m_q.p.d);   push_state(17);	// LD16
goto INDEXED;
		case 0x42:              set_regop16(m_x);       set_imm();  goto LD16;
		case 0x43:              set_regop16(m_x);       push_state(17);	// LD16
goto INDEXED;
		case 0x44:              set_regop16(m_y);       set_imm();  goto LD16;
		case 0x45:              set_regop16(m_y);       push_state(17);	// LD16
goto INDEXED;
		case 0x46:              set_regop16(m_u);       set_imm();  goto LD16;
		case 0x47:              set_regop16(m_u);       push_state(17);	// LD16
goto INDEXED;
		case 0x48:              set_regop16(m_s);       set_imm();  goto LD16;
		case 0x49:              set_regop16(m_s);       push_state(17);	// LD16
goto INDEXED;
		case 0x4A:              set_regop16(m_q.p.d);   set_imm();  goto CMP16;
		case 0x4B:              set_regop16(m_q.p.d);   push_state(18);	// CMP16
goto INDEXED;
		case 0x4C:              set_regop16(m_x);       set_imm();  goto CMP16;
		case 0x4D:              set_regop16(m_x);       push_state(18);	// CMP16
goto INDEXED;
		case 0x4E:              set_regop16(m_y);       set_imm();  goto CMP16;
		case 0x4F:              set_regop16(m_y);       push_state(18);	// CMP16
goto INDEXED;

		case 0x50:              set_regop16(m_u);       set_imm();  goto CMP16;
		case 0x51:              set_regop16(m_u);       push_state(18);	// CMP16
goto INDEXED;
		case 0x52:              set_regop16(m_s);       set_imm();  goto CMP16;
		case 0x53:              set_regop16(m_s);       push_state(18);	// CMP16
goto INDEXED;
		case 0x54:              set_regop16(m_q.p.d);   set_imm();  goto ADD16;
		case 0x55:              set_regop16(m_q.p.d);   push_state(19);	// ADD16
goto INDEXED;
		case 0x56:              set_regop16(m_q.p.d);   set_imm();  goto SUB16;
		case 0x57:              set_regop16(m_q.p.d);   push_state(20);	// SUB16
goto INDEXED;
		case 0x58:              set_regop16(m_q.p.d);   push_state(21);	// ST16
goto INDEXED;
		case 0x59:              set_regop16(m_x);       push_state(21);	// ST16
goto INDEXED;
		case 0x5A:              set_regop16(m_y);       push_state(21);	// ST16
goto INDEXED;
		case 0x5B:              set_regop16(m_u);       push_state(21);	// ST16
goto INDEXED;
		case 0x5C:              set_regop16(m_s);       push_state(21);	// ST16
goto INDEXED;

		case 0x60:              set_cond(true);                     goto BRANCH;
		case 0x61:              set_cond(cond_hi());                goto BRANCH;
		case 0x62:              set_cond(cond_cc());                goto BRANCH;
		case 0x63:              set_cond(cond_ne());                goto BRANCH;
		case 0x64:              set_cond(cond_vc());                goto BRANCH;
		case 0x65:              set_cond(cond_pl());                goto BRANCH;
		case 0x66:              set_cond(cond_ge());                goto BRANCH;
		case 0x67:              set_cond(cond_gt());                goto BRANCH;
		case 0x68:              set_cond(true);                     goto LBRANCH;
		case 0x69:              set_cond(cond_hi());                goto LBRANCH;
		case 0x6A:              set_cond(cond_cc());                goto LBRANCH;
		case 0x6B:              set_cond(cond_ne());                goto LBRANCH;
		case 0x6C:              set_cond(cond_vc());                goto LBRANCH;
		case 0x6D:              set_cond(cond_pl());                goto LBRANCH;
		case 0x6E:              set_cond(cond_ge());                goto LBRANCH;
		case 0x6F:              set_cond(cond_gt());                goto LBRANCH;

		case 0x70:              set_cond(false);                    goto BRANCH;
		case 0x71:              set_cond(!cond_hi());               goto BRANCH;
		case 0x72:              set_cond(!cond_cc());               goto BRANCH;
		case 0x73:              set_cond(!cond_ne());               goto BRANCH;
		case 0x74:              set_cond(!cond_vc());               goto BRANCH;
		case 0x75:              set_cond(!cond_pl());               goto BRANCH;
		case 0x76:              set_cond(!cond_ge());               goto BRANCH;
		case 0x77:              set_cond(!cond_gt());               goto BRANCH;
		case 0x78:              set_cond(false);                    goto LBRANCH;
		case 0x79:              set_cond(!cond_hi());               goto LBRANCH;
		case 0x7A:              set_cond(!cond_cc());               goto LBRANCH;
		case 0x7B:              set_cond(!cond_ne());               goto LBRANCH;
		case 0x7C:              set_cond(!cond_vc());               goto LBRANCH;
		case 0x7D:              set_cond(!cond_pl());               goto LBRANCH;
		case 0x7E:              set_cond(!cond_ge());               goto LBRANCH;
		case 0x7F:              set_cond(!cond_gt());               goto LBRANCH;

		case 0x80:                                      set_a();    goto CLR8;
		case 0x81:                                      set_b();    goto CLR8;
		case 0x82:
			push_state(22);	// CLR8
			goto INDEXED;
		case 0x83:                                      set_a();    goto COM8;
		case 0x84:                                      set_b();    goto COM8;
		case 0x85:
			push_state(23);	// COM8
			goto INDEXED;
		case 0x86:                                      set_a();    goto NEG8;
		case 0x87:                                      set_b();    goto NEG8;
		case 0x88:
			push_state(24);	// NEG8
			goto INDEXED;
		case 0x89:                                      set_a();    goto INC8;
		case 0x8A:                                      set_b();    goto INC8;
		case 0x8B:
			push_state(25);	// INC8
			goto INDEXED;
		case 0x8C:                                      set_a();    goto DEC8;
		case 0x8D:                                      set_b();    goto DEC8;
		case 0x8E:
			push_state(26);	// DEC8
			goto INDEXED;
		case 0x8F:
			goto RTS;

		case 0x90:                                      set_a();    goto TST8;
		case 0x91:                                      set_b();    goto TST8;
		case 0x92:
			push_state(27);	// TST8
			goto INDEXED;
		case 0x93:                                      set_a();    goto LSR8;
		case 0x94:                                      set_b();    goto LSR8;
		case 0x95:
			push_state(28);	// LSR8
			goto INDEXED;
		case 0x96:                                      set_a();    goto ROR8;
		case 0x97:                                      set_b();    goto ROR8;
		case 0x98:
			push_state(29);	// ROR8
			goto INDEXED;
		case 0x99:                                      set_a();    goto ASR8;
		case 0x9A:                                      set_b();    goto ASR8;
		case 0x9B:
			push_state(30);	// ASR8
			goto INDEXED;
		case 0x9C:                                      set_a();    goto ASL8;
		case 0x9D:                                      set_b();    goto ASL8;
		case 0x9E:
			push_state(31);	// ASL8
			goto INDEXED;
		case 0x9F:
			goto RTI;

		case 0xA0:                                      set_a();    goto ROL8;
		case 0xA1:                                      set_b();    goto ROL8;
		case 0xA2:
			push_state(32);	// ROL8
			goto INDEXED;
		case 0xA3:
			push_state(33);	// LSR16
			goto INDEXED;
		case 0xA4:
			push_state(34);	// ROR16
			goto INDEXED;
		case 0xA5:
			push_state(35);	// ASR16
			goto INDEXED;
		case 0xA6:
			push_state(36);	// ASL16
			goto INDEXED;
		case 0xA7:
			push_state(37);	// ROL16
			goto INDEXED;
		case 0xA8:
			push_state(38);	// JMP
			goto INDEXED;
		case 0xA9:
			push_state(39);	// JSR
			goto INDEXED;
		case 0xAA:
			goto BSR;
		case 0xAB:
			goto LBSR;
		case 0xAC:
			goto DBJNZ;
		case 0xAD:
			goto DXJNZ;
		case 0xAE:
			goto NOP;

		case 0xB0:
			goto ABX;
		case 0xB1:
			goto DAA;
		case 0xB2:
			goto SEX;
		case 0xB3:
			goto MUL;
		case 0xB4:
			goto LMUL;
		case 0xB5:
			goto DIVX;
		case 0xB6:
			goto BMOVE;
		case 0xB7:
			goto MOVE;
		case 0xB8:
			push_state(40);
			goto IMM_IM;
state_40:
set_d();    goto LSRDI;
		case 0xB9:
			push_state(41);	// LSRDI
			goto INDEXED;
		case 0xBA:
			push_state(42);
			goto IMM_IM;
state_42:
set_d();    goto RORDI;
		case 0xBB:
			push_state(43);	// RORDI
			goto INDEXED;
		case 0xBC:
			push_state(44);
			goto IMM_IM;
state_44:
set_d();    goto ASRDI;
		case 0xBD:
			push_state(45);	// ASRDI
			goto INDEXED;
		case 0xBE:
			push_state(46);
			goto IMM_IM;
state_46:
set_d();    goto ASLDI;
		case 0xBF:
			push_state(47);	// ASLDI
			goto INDEXED;

		case 0xC0:
			push_state(48);
			goto IMM_IM;
state_48:
set_d();    goto ROLDI;
		case 0xC1:
			push_state(49);	// ROLDI
			goto INDEXED;
		case 0xC2:                                      set_d();    goto CLR16;
		case 0xC3:
			push_state(50);	// CLR16
			goto INDEXED;
		case 0xC4:                                      set_d();    goto NEG16;
		case 0xC5:
			push_state(51);	// NEG16
			goto INDEXED;
		case 0xC6:                                      set_d();    goto INC16;
		case 0xC7:
			push_state(52);	// INC16
			goto INDEXED;
		case 0xC8:                                      set_d();    goto DEC16;
		case 0xC9:
			push_state(53);	// DEC16
			goto INDEXED;
		case 0xCA:                                      set_d();    goto TST16;
		case 0xCB:
			push_state(54);	// TST16
			goto INDEXED;
		case 0xCC:                                      set_a();    goto ABS8;
		case 0xCD:                                      set_b();    goto ABS8;
		case 0xCE:                                      set_d();    goto ABS16;
		case 0xCF:
			goto BSET;

		case 0xD0:
			goto BSETW;
		default:
			goto ILLEGAL;
	}
	return;

// license:BSD-3-Clause
// copyright-holders:Nathan Woods
NMI:
	m_nmi_asserted = false;
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(55); return; }
state_55:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(56); return; }
state_56:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(57); return; }
state_57:
	m_cc |= CC_E;
	set_regop16(m_s);
	m_temp.w = entire_state_registers();
	push_state(58);
	goto PUSH_REGISTERS;
state_58:
	m_cc |= CC_I | CC_F;
	set_ea(VECTOR_NMI);
	standard_irq_callback(INPUT_LINE_NMI, m_pc.w);
	goto INTERRUPT_VECTOR;

FIRQ:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(59); return; }
state_59:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(60); return; }
state_60:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(61); return; }
state_61:
	if (firq_saves_entire_state())
	{
		m_cc |= CC_E;
		m_temp.w = entire_state_registers();
	}
	else
	{
		m_cc &= ~CC_E;
		m_temp.w = partial_state_registers();
	}
	set_regop16(m_s);
	push_state(62);
	goto PUSH_REGISTERS;
state_62:
	m_cc |= CC_I | CC_F;
	set_ea(VECTOR_FIRQ);
	standard_irq_callback(M6809_FIRQ_LINE, m_pc.w);
	goto INTERRUPT_VECTOR;

IRQ:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(63); return; }
state_63:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(64); return; }
state_64:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(65); return; }
state_65:
	m_cc |= CC_E;
	set_regop16(m_s);
	m_temp.w = entire_state_registers();
	push_state(66);
	goto PUSH_REGISTERS;
state_66:
	m_cc |= CC_I;
	set_ea(VECTOR_IRQ);
	standard_irq_callback(M6809_IRQ_LINE, m_pc.w);
	goto INTERRUPT_VECTOR;

INTERRUPT_VECTOR:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(67); return; }
state_67:
	m_pc.b.h = read_vector(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(68); return; }
state_68:
	m_pc.b.l = read_vector(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(69); return; }
state_69:
	dummy_vma(1);
	return;

NEG8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(70); return; }
state_70:
	m_temp.b.l = set_flags(CC_NZVC, (uint8_t)0, m_temp.b.l, -m_temp.b.l);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(71); return; }
state_71:
		;
	}
	write_operand(m_temp.b.l);
	return;

COM8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(72); return; }
state_72:
	m_cc &= ~CC_V;
	m_cc |= CC_C;
	m_temp.b.l = set_flags(CC_NZ, (uint8_t) ~m_temp.b.l);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(73); return; }
state_73:
		;
	}
	write_operand(m_temp.b.l);
	return;

LSR8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(74); return; }
state_74:
	m_cc &= ~CC_C;
	m_cc |= (m_temp.b.l & 1) ? CC_C : 0;
	m_temp.b.l = set_flags<uint8_t>(CC_NZ, m_temp.b.l >> 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(75); return; }
state_75:
		;
	}
	write_operand(m_temp.b.l);
	return;

ROR8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(76); return; }
state_76:
	m_temp.b.l = set_flags<uint8_t>(CC_NZ, rotate_right(m_temp.b.l));
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(77); return; }
state_77:
		;
	}
	write_operand(m_temp.b.l);
	return;

ASR8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(78); return; }
state_78:
	m_cc &= ~CC_C;
	m_cc |= (m_temp.b.l & 1) ? CC_C : 0;
	m_temp.b.l = set_flags<uint8_t>(CC_NZ, ((int8_t) m_temp.b.l) >> 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(79); return; }
state_79:
		;
	}
	write_operand(m_temp.b.l);
	return;

ASL8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(80); return; }
state_80:
	m_temp.b.l = set_flags<uint8_t>(CC_NZVC, m_temp.b.l, m_temp.b.l, m_temp.b.l << 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(81); return; }
state_81:
		;
	}
	write_operand(m_temp.b.l);
	return;

ROL8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(82); return; }
state_82:
	m_temp.b.l = set_flags<uint8_t>(CC_NZV, m_temp.b.l, m_temp.b.l, rotate_left(m_temp.b.l));
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(83); return; }
state_83:
		;
	}
	write_operand(m_temp.b.l);
	return;

DEC8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(84); return; }
state_84:
	m_temp.b.l = set_flags<uint8_t>(CC_NZV, m_temp.b.l, 1, m_temp.b.l - 1);
	if(!hd6309_native_mode() || !is_register_addressing_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(85); return; }
state_85:
		;
	}
	write_operand(m_temp.b.l);
	return;

INC8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(86); return; }
state_86:
	m_temp.b.l = set_flags<uint8_t>(CC_NZV, m_temp.b.l, 1, m_temp.b.l + 1);
	if(!hd6309_native_mode() || !is_register_addressing_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(87); return; }
state_87:
		;
	}
	write_operand(m_temp.b.l);
	return;

TST8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(88); return; }
state_88:
	set_flags(CC_NZV, m_temp.b.l);
	if(!hd6309_native_mode())
	{
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(89); return; }
state_89:
		;
	}
	if(!is_register_addressing_mode())
	{
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(90); return; }
state_90:
		;
	}
	return;

JMP:
	m_pc.w = m_ea.w;
	return;

CLR8:
	read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(91); return; }
state_91:
	m_cc &= ~CC_NZVC;
	m_cc |= CC_Z;
	if(!hd6309_native_mode() || !is_register_addressing_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(92); return; }
state_92:
		;
	}
	write_operand(0);
	return;

NEG16:
	m_temp.b.h = read_operand(0);
	m_temp.b.l = read_operand(1);
	m_temp.w = set_flags(CC_NZVC, (uint16_t)0, m_temp.w, -m_temp.w);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(93); return; }
state_93:
		;
	}
	write_operand(0, m_temp.b.h);
	write_operand(1, m_temp.b.l);
	return;

LSR16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(94); return; }
state_94:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(95); return; }
state_95:
	m_cc &= ~CC_C;
	m_cc |= (m_temp.w & 1) ? CC_C : 0;
	m_temp.w = set_flags<uint16_t>(CC_NZ, m_temp.w >> 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(96); return; }
state_96:
		;
	}
	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(97); return; }
state_97:
	write_operand(1, m_temp.b.l);
	return;

ROR16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(98); return; }
state_98:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(99); return; }
state_99:
	m_temp.w = set_flags<uint16_t>(CC_NZ, rotate_right(m_temp.w));
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(100); return; }
state_100:
		;
	}
	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(101); return; }
state_101:
	write_operand(1, m_temp.b.l);
	return;

ASR16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(102); return; }
state_102:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(103); return; }
state_103:
	m_cc &= ~CC_C;
	m_cc |= (m_temp.w & 1) ? CC_C : 0;
	m_temp.w = set_flags<uint16_t>(CC_NZ, ((int16_t) m_temp.w) >> 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(104); return; }
state_104:
		;
	}
	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(105); return; }
state_105:
	write_operand(1, m_temp.b.l);
	return;

ASL16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(106); return; }
state_106:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(107); return; }
state_107:
	m_temp.w = set_flags<uint16_t>(CC_NZVC, m_temp.w, m_temp.w, m_temp.w << 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(108); return; }
state_108:
		;
	}
	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(109); return; }
state_109:
	write_operand(1, m_temp.b.l);
	return;

ROL16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(110); return; }
state_110:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(111); return; }
state_111:
	m_temp.w = set_flags<uint16_t>(CC_NZV, rotate_left(m_temp.w));
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(112); return; }
state_112:
		;
	}
	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(113); return; }
state_113:
	write_operand(1, m_temp.b.l);
	return;

DEC16:
	m_temp.b.h = read_operand(0);
	m_temp.b.l = read_operand(1);
	m_temp.w = set_flags<uint16_t>(CC_NZVC, m_temp.w, 1, m_temp.w - 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(114); return; }
state_114:
		;
	}
	write_operand(0, m_temp.b.h);
	write_operand(1, m_temp.b.l);
	return;

INC16:
	m_temp.b.h = read_operand(0);
	m_temp.b.l = read_operand(1);
	m_temp.w = set_flags<uint16_t>(CC_NZVC, m_temp.w, 1, m_temp.w + 1);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(115); return; }
state_115:
		;
	}
	write_operand(0, m_temp.b.h);
	write_operand(1, m_temp.b.l);
	return;

TST16:
	m_temp.b.h = read_operand(0);
	m_temp.b.l = read_operand(1);
	set_flags(CC_NZV, m_temp.w);
	if(!hd6309_native_mode())
	{
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(116); return; }
state_116:
		;
	}
	if(!is_register_addressing_mode())
	{
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(117); return; }
state_117:
		;
	}
	return;

CLR16:
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(118); return; }
state_118:
		;
	}
	m_cc &= ~CC_NZVC;
	m_cc |= CC_Z;
	write_operand(0, 0x00);
	write_operand(1, 0x00);
	return;

SUB8:
	m_temp.b.l = read_operand();
	regop8() = set_flags(CC_NZVC, regop8(), m_temp.b.l, regop8() - m_temp.b.l);
	return;

CMP8:
	m_temp.b.l = read_operand();
	set_flags(CC_NZVC, regop8(), m_temp.b.l, regop8() - m_temp.b.l);
	return;

SBC8:
	m_temp.b.l = read_operand();
	regop8() = set_flags(CC_NZVC, regop8(), m_temp.b.l, regop8() - m_temp.b.l - (m_cc & CC_C ? 1 : 0));
	return;

AND8:
	m_cc &= ~CC_V;
	regop8() = set_flags(CC_NZ, (uint8_t)0, regop8(), regop8() & read_operand());
	return;

BIT8:
	m_cc &= ~CC_V;
	set_flags(CC_NZ, (uint8_t)0, regop8(), regop8() & read_operand());
	return;

EOR8:
	m_cc &= ~CC_V;
	regop8() = set_flags(CC_NZ, (uint8_t)0, regop8(), regop8() ^ read_operand());
	return;

ADC8:
	m_temp.b.l = read_operand();
	regop8() = set_flags(add8_sets_h() ? CC_HNZVC : CC_NZVC, regop8(), m_temp.b.l, regop8() + m_temp.b.l + (m_cc & CC_C ? 1 : 0));
	return;

OR8:
	m_cc &= ~CC_V;
	regop8() = set_flags(CC_NZ, (uint8_t)0, regop8(), regop8() | read_operand());
	return;

ADD8:
	m_temp.b.l = read_operand();
	regop8() = set_flags(add8_sets_h() ? CC_HNZVC : CC_NZVC, regop8(), m_temp.b.l, regop8() + m_temp.b.l);
	return;

ADD16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(119); return; }
state_119:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(120); return; }
state_120:
	regop16().w = set_flags(CC_NZVC, regop16().w, m_temp.w, regop16().w + m_temp.w);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(121); return; }
state_121:
		;
	}
	return;

SUB16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(122); return; }
state_122:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(123); return; }
state_123:
	regop16().w = set_flags(CC_NZVC, regop16().w, m_temp.w, regop16().w - m_temp.w);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(124); return; }
state_124:
		;
	}
	return;

CMP16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(125); return; }
state_125:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(126); return; }
state_126:
	set_flags(CC_NZVC, regop16().w, m_temp.w, regop16().w - m_temp.w);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(127); return; }
state_127:
		;
	}
	return;

LD8:
	regop8() = read_operand();
	set_flags(CC_NZV, regop8());
	return;

LD16:
	regop16().b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(128); return; }
state_128:
	regop16().b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(129); return; }
state_129:
	set_flags(CC_NZV, regop16().w);
	if (&regop16() == &m_s)
		m_lds_encountered = true;
	return;

ST8:
	write_ea(set_flags(CC_NZV, regop8()));
	return;

ST16:
	write_operand(0, regop16().b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(130); return; }
state_130:
	write_operand(1, regop16().b.l);
	if (UNEXPECTED(m_icount <= 0)) { push_state(131); return; }
state_131:
	set_flags(CC_NZV, regop16().w);
	return;

NOP:
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(132); return; }
state_132:
		;
	}
	return;

SYNC:
	// SYNC stops processing instructions until an interrupt request happens.
	// This doesn't require the corresponding interrupt to be enabled: if it
	// is disabled, execution continues with the next instruction.
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(133); return; }
state_133:

	m_syncack_write_func(1);
	while(!m_nmi_asserted && !m_firq_line && !m_irq_line)
	{
		eat_remaining();
		if (UNEXPECTED(m_icount <= 0)) { push_state(134); return; }
state_134:
		;
	}
	m_syncack_write_func(0);
	eat(1);
	return;

DAA:
	daa();
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(135); return; }
state_135:
		;
	}
	return;

ORCC:
	m_cc |= read_operand();
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(136); return; }
state_136:
		;
	}
	return;

ANDCC:
	m_cc &= read_operand();
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(137); return; }
state_137:
		;
	}
	return;

SEX:
	m_q.r.d = set_flags<uint16_t>(CC_NZ, (int8_t) m_q.r.b);
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(138); return; }
state_138:
		;
	}
	return;

BRANCH:
	m_temp.b.l = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(139); return; }
state_139:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(140); return; }
state_140:
	if (branch_taken())
	{
		m_pc.w += (int8_t) m_temp.b.l;
	}
	return;

LBRANCH:
	m_temp.b.h = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(141); return; }
state_141:
	m_temp.b.l = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(142); return; }
state_142:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(143); return; }
state_143:
	if (branch_taken())
	{
		m_pc.w += m_temp.w;
		if(!hd6309_native_mode())
		{
			dummy_vma(1);
			if (UNEXPECTED(m_icount <= 0)) { push_state(144); return; }
state_144:
			;
		}
	}
	return;

BSR:
	m_temp.b.l = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(145); return; }
state_145:
	m_ea.w = m_pc.w + (int8_t) m_temp.b.l;
	dummy_vma(hd6309_native_mode() ? 2 : 3);
	if (UNEXPECTED(m_icount <= 0)) { push_state(146); return; }
state_146:
	goto GOTO_SUBROUTINE;

LBSR:
	m_temp.b.h = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(147); return; }
state_147:
	m_temp.b.l = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(148); return; }
state_148:
	m_ea.w = m_pc.w + (int16_t) m_temp.w;
	dummy_vma(hd6309_native_mode() ? 2 : 4);
	if (UNEXPECTED(m_icount <= 0)) { push_state(149); return; }
state_149:
	goto GOTO_SUBROUTINE;

JSR:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(150); return; }
state_150:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(151); return; }
state_151:
	goto GOTO_SUBROUTINE;

GOTO_SUBROUTINE:
	write_memory(--m_s.w, m_pc.b.l);
	if (UNEXPECTED(m_icount <= 0)) { push_state(152); return; }
state_152:
	write_memory(--m_s.w, m_pc.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(153); return; }
state_153:
	m_pc.w = m_ea.w;
	return;

RTS:
	m_temp.w = 0x80; // RTS is equivalent to "PULS PC"
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(154); return; }
state_154:
		;
	}
	set_regop16(m_s);
	goto PULL_REGISTERS;

ABX:
	m_x.w += m_q.r.b;
	if(!hd6309_native_mode())
	{
		dummy_read_opcode_arg(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(155); return; }
state_155:
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(156); return; }
state_156:
		;
	}
	return;

MUL:
	mul();
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(157); return; }
state_157:
	dummy_vma(hd6309_native_mode() ? 8 : 9);
	return;

RTI:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(158); return; }
state_158:
	set_regop16(m_s);
	m_cc = read_memory(regop16().w++); 	if (UNEXPECTED(m_icount <= 0)) { push_state(159); return; }
state_159:
// PULS CC
	m_temp.w = ((m_cc & CC_E) ? entire_state_registers() : partial_state_registers()) & ~0x01;
	goto PULL_REGISTERS;

CWAI:
	m_cc &= read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(160); return; }
state_160:
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(161); return; }
state_161:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(162); return; }
state_162:

	m_cc |= CC_E;
	set_regop16(m_s);
	m_temp.w = entire_state_registers();
	push_state(163);
	goto PUSH_REGISTERS;
state_163:

	while((m_ea.w = get_pending_interrupt()) == 0)
	{
		eat_remaining();
		if (UNEXPECTED(m_icount <= 0)) { push_state(164); return; }
state_164:
		;
	}

	if (m_nmi_asserted)
		m_nmi_asserted = false;

	set_ea(m_ea.w); // need to do this to set the addressing mode
	m_cc |= CC_I | (m_ea.w != VECTOR_IRQ ? CC_F : 0);

	// invoke standard interrupt callback for MAME core
	switch (m_ea.w)
	{
		case VECTOR_NMI:    standard_irq_callback(INPUT_LINE_NMI, m_pc.w); break;
		case VECTOR_FIRQ:   standard_irq_callback(M6809_FIRQ_LINE, m_pc.w); break;
		case VECTOR_IRQ:    standard_irq_callback(M6809_IRQ_LINE, m_pc.w); break;
		default:            break;
	}

	goto INTERRUPT_VECTOR;

LEA_xy:
	regop16().w = set_flags(CC_Z, m_ea.w);
	dummy_vma(1);
	return;

LEA_us:
	if (&regop16() == &m_s)
		m_lds_encountered = true;
	regop16().w = m_ea.w;
	dummy_vma(1);
	return;

PSHS:
	m_temp.w = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(165); return; }
state_165:
	dummy_vma(2);
	if (UNEXPECTED(m_icount <= 0)) { push_state(166); return; }
state_166:
	set_regop16(m_s);
	if(!hd6309_native_mode())
	{
		(void)read_memory(regop16().w);
		if (UNEXPECTED(m_icount <= 0)) { push_state(167); return; }
state_167:
		;
	}
	goto PUSH_REGISTERS;

PULS:
	m_temp.w = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(168); return; }
state_168:
	dummy_vma(hd6309_native_mode() ? 1 : 2);
	if (UNEXPECTED(m_icount <= 0)) { push_state(169); return; }
state_169:
	set_regop16(m_s);
	goto PULL_REGISTERS;

PSHU:
	m_temp.w = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(170); return; }
state_170:
	dummy_vma(2);
	if (UNEXPECTED(m_icount <= 0)) { push_state(171); return; }
state_171:
	set_regop16(m_u);
	if(!hd6309_native_mode())
	{
		(void)read_memory(regop16().w);
		if (UNEXPECTED(m_icount <= 0)) { push_state(172); return; }
state_172:
		;
	}
	goto PUSH_REGISTERS;

PULU:
	m_temp.w = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(173); return; }
state_173:
	dummy_vma(hd6309_native_mode() ? 1 : 2);
	if (UNEXPECTED(m_icount <= 0)) { push_state(174); return; }
state_174:
	set_regop16(m_u);
	goto PULL_REGISTERS;

SWI:
	// doesn't use SOFTWARE_INTERRUPT label because SWI will
	// inhibit IRQ/FIRQ
	set_ea(VECTOR_SWI);
	debugger_exception_hook(EXCEPTION_SWI);
	m_cc |= CC_E;
	set_regop16(m_s);
	m_temp.w = entire_state_registers();
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(175); return; }
state_175:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(176); return; }
state_176:
	push_state(177);
	goto PUSH_REGISTERS;
state_177:
	m_cc |= CC_I | CC_F;
	goto INTERRUPT_VECTOR;

SWI2:
	set_ea(VECTOR_SWI2);
	debugger_exception_hook(EXCEPTION_SWI2);
	goto SOFTWARE_INTERRUPT;

SWI3:
	set_ea(VECTOR_SWI3);
	debugger_exception_hook(EXCEPTION_SWI3);
	goto SOFTWARE_INTERRUPT;

SOFTWARE_INTERRUPT:
	// used for SWI2/SWI3 and illegal/div0 on 6309
	m_cc |= CC_E;
	set_regop16(m_s);
	m_temp.w = entire_state_registers();
	dummy_read_opcode_arg(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(178); return; }
state_178:
	dummy_vma(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(179); return; }
state_179:
	push_state(180);
	goto PUSH_REGISTERS;
state_180:
	goto INTERRUPT_VECTOR;

DIRECT:
	set_ea(((uint16_t)m_dp << 8) | read_opcode_arg());
	if (UNEXPECTED(m_icount <= 0)) { push_state(181); return; }
state_181:
	if(!hd6309_native_mode())
	{
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(182); return; }
state_182:
		;
	}
	return;

EXTENDED:
	set_ea_h(read_opcode_arg());
	if (UNEXPECTED(m_icount <= 0)) { push_state(183); return; }
state_183:
	set_ea_l(read_opcode_arg());
	if (UNEXPECTED(m_icount <= 0)) { push_state(184); return; }
state_184:
	if(!hd6309_native_mode())
	{
		dummy_vma(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(185); return; }
state_185:
		;
	}
	return;

PUSH_REGISTERS:
	if (m_temp.w & 0x80)
	{
		write_memory(--regop16().w, m_pc.b.l);
		if (UNEXPECTED(m_icount <= 0)) { push_state(186); return; }
state_186:
		write_memory(--regop16().w, m_pc.b.h);
		if (UNEXPECTED(m_icount <= 0)) { push_state(187); return; }
state_187:
		nop();
	}
	if (m_temp.w & 0x40)
	{
		write_memory(--regop16().w, (&regop16() == &m_s) ? m_u.b.l : m_s.b.l);
		if (UNEXPECTED(m_icount <= 0)) { push_state(188); return; }
state_188:
		write_memory(--regop16().w, (&regop16() == &m_s) ? m_u.b.h : m_s.b.h);
		if (UNEXPECTED(m_icount <= 0)) { push_state(189); return; }
state_189:
		nop();
	}
	if (m_temp.w & 0x20)
	{
		write_memory(--regop16().w, m_y.b.l);
		if (UNEXPECTED(m_icount <= 0)) { push_state(190); return; }
state_190:
		write_memory(--regop16().w, m_y.b.h);
		if (UNEXPECTED(m_icount <= 0)) { push_state(191); return; }
state_191:
		nop();
	}
	if (m_temp.w & 0x10)
	{
		write_memory(--regop16().w, m_x.b.l);
		if (UNEXPECTED(m_icount <= 0)) { push_state(192); return; }
state_192:
		write_memory(--regop16().w, m_x.b.h);
		if (UNEXPECTED(m_icount <= 0)) { push_state(193); return; }
state_193:
		nop();
	}
	if (m_temp.w & 0x08)
	{
		write_memory(--regop16().w, m_dp);
		if (UNEXPECTED(m_icount <= 0)) { push_state(194); return; }
state_194:
		nop();
	}
	if (m_temp.w & 0x04)
	{
		write_memory(--regop16().w, m_q.r.b);
		if (UNEXPECTED(m_icount <= 0)) { push_state(195); return; }
state_195:
		nop();
	}
	if (m_temp.w & 0x02)
	{
		write_memory(--regop16().w, m_q.r.a);
		if (UNEXPECTED(m_icount <= 0)) { push_state(196); return; }
state_196:
		nop();
	}
	if (m_temp.w & 0x01)
	{
		write_memory(--regop16().w, m_cc);
		if (UNEXPECTED(m_icount <= 0)) { push_state(197); return; }
state_197:
		nop();
	}
	return;

PULL_REGISTERS:
	if (m_temp.w & 0x01)
	{
		m_cc = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(198); return; }
state_198:
		nop();
	}
	if (m_temp.w & 0x02)
	{
		m_q.r.a = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(199); return; }
state_199:
		nop();
	}
	if (m_temp.w & 0x04)
	{
		m_q.r.b = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(200); return; }
state_200:
		nop();
	}
	if (m_temp.w & 0x08)
	{
		m_dp = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(201); return; }
state_201:
		nop();
	}
	if (m_temp.w & 0x10)
	{
		m_x.b.h = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(202); return; }
state_202:
		m_x.b.l = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(203); return; }
state_203:
		nop();
	}
	if (m_temp.w & 0x20)
	{
		m_y.b.h = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(204); return; }
state_204:
		m_y.b.l = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(205); return; }
state_205:
		nop();
	}
	if (m_temp.w & 0x40)
	{
		(&regop16() == &m_s ? m_u : m_s).b.h = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(206); return; }
state_206:
		(&regop16() == &m_s ? m_u : m_s).b.l = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(207); return; }
state_207:
		nop();
	}
	if (m_temp.w & 0x80)
	{
		m_pc.b.h = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(208); return; }
state_208:
		m_pc.b.l = read_memory(regop16().w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(209); return; }
state_209:
		nop();
	}
	eat(1);
	return;

INDEXED:
	m_opcode = read_opcode_arg();
	if (UNEXPECTED(m_icount <= 0)) { push_state(210); return; }
state_210:
	switch(m_opcode & 0xF7)
	{
		case 0x07:
			// extended addressing mode
			m_temp.b.h = read_opcode_arg();
			if (UNEXPECTED(m_icount <= 0)) { push_state(211); return; }
state_211:
			m_temp.b.l = read_opcode_arg();
			if (UNEXPECTED(m_icount <= 0)) { push_state(212); return; }
state_212:
			eat(1);
			break;

		case 0x20: case 0x30: case 0x50: case 0x60: case 0x70:
			// auto increment
			m_temp.w = ireg();
			ireg()++;
			eat(2);
			break;

		case 0x21: case 0x31: case 0x51: case 0x61: case 0x71:
			// double auto increment
			m_temp.w = ireg();
			ireg() += 2;
			eat(3);
			break;

		case 0x22: case 0x32: case 0x52: case 0x62: case 0x72:
			// auto decrement
			ireg()--;
			m_temp.w = ireg();
			eat(2);
			break;

		case 0x23: case 0x33: case 0x53: case 0x63: case 0x73:
			// double auto decrement
			ireg() -= 2;
			m_temp.w = ireg();
			eat(3);
			break;

		case 0x24: case 0x34: case 0x54: case 0x64: case 0x74:
			// postbyte offset
			m_ea.w = ireg(); // need to do this now because ireg() might be PC
			m_temp.b.l = read_opcode_arg();
			if (UNEXPECTED(m_icount <= 0)) { push_state(213); return; }
state_213:
			m_temp.w = m_ea.w + (int8_t) m_temp.b.l;
			eat(2);
			break;

		case 0x25: case 0x35: case 0x55: case 0x65: case 0x75:
			// postword offset
			m_ea.w = ireg(); // need to do this now because ireg() might be PC
			m_temp.b.h = read_opcode_arg();
			if (UNEXPECTED(m_icount <= 0)) { push_state(214); return; }
state_214:
			m_temp.b.l = read_opcode_arg();
			if (UNEXPECTED(m_icount <= 0)) { push_state(215); return; }
state_215:
			m_temp.w = m_ea.w + (int16_t) m_temp.w;
			eat(2);
			break;

		case 0x26: case 0x36: case 0x56: case 0x66: case 0x76:
			m_temp.w = ireg();
			eat(1);
			break;

		case 0xC4:
			// direct addressing mode
			m_temp.b.h = m_dp;
			m_temp.b.l = read_opcode_arg();
			if (UNEXPECTED(m_icount <= 0)) { push_state(216); return; }
state_216:
			eat(1);
			break;

		case 0xA0: case 0xB0: case 0xD0: case 0xE0: case 0xF0:
			// relative to register A
			m_temp.w = ireg() + (int8_t) m_q.r.a;
			eat(2);
			break;

		case 0xA1: case 0xB1: case 0xD1: case 0xE1: case 0xF1:
			// relative to register B
			m_temp.w = ireg() + (int8_t) m_q.r.b;
			eat(2);
			break;

		case 0xA7: case 0xB7: case 0xD7: case 0xE7: case 0xF7:
			// relative to register D
			m_temp.w = ireg() + (int16_t) m_q.r.d;
			eat(2);
			break;

		default:
			logerror("KONAMI: Unknown/Invalid postbyte at PC = %04x\n", m_pc.w - 1);
			m_temp.w = 0;
			break;
	}

	if (m_opcode & 0x08)
	{
		// indirect mode
		set_ea(m_temp.w);
		m_temp.b.h = read_operand(0);
		if (UNEXPECTED(m_icount <= 0)) { push_state(217); return; }
state_217:
		m_temp.b.l = read_operand(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(218); return; }
state_218:
		eat(1);
	}

	set_ea(m_temp.w);
	return;

EXGTFR:
	{
		// konami's EXG/TFR instruction differs enough from HD6309 to fork the code
		uint8_t param = read_opcode_arg();
		uint16_t reg = read_exgtfr_register(param >> 0);

		// Opcodes 0x3E and 0x3F are the same! The bit that distinguishes between EXG and TFR
		// is actually opcode_arg bit 7. Although Konami software behaves as expected.
		if (!BIT(param, 7))
		{
			uint16_t reg2 = read_exgtfr_register(param >> 4);
			write_exgtfr_register(param >> 0, reg2);
			eat(1);
		}
		write_exgtfr_register(param >> 4, reg);

		//if (BIT(m_opcode, 0) != BIT(param, 7))
		//  logerror("KONAMI: Malformed EXG/TFR opcode\n");
	}
	eat(2);
	return;

SETLN:
	set_lines(read_operand());
	return;

IMM_IM:
	m_temp_im = read_opcode_arg();
	return;

MOVE:
	m_temp.b.l = read_memory(m_y.w++);
	if (UNEXPECTED(m_icount <= 0)) { push_state(219); return; }
state_219:
	write_memory(m_x.w++, m_temp.b.l);
	if (UNEXPECTED(m_icount <= 0)) { push_state(220); return; }
state_220:
	m_u.w--;
	return;

BMOVE:
	// BMOVE does not appear to be interruptable, at least judging from the old implementation
	while(m_u.w != 0)
	{
		m_temp.b.l = read_memory(m_y.w++);
		if (UNEXPECTED(m_icount <= 0)) { push_state(221); return; }
state_221:
		write_memory(m_x.w++, m_temp.b.l);
		if (UNEXPECTED(m_icount <= 0)) { push_state(222); return; }
state_222:
		m_u.w--;
	}
	return;

BSET:
	// BSET does not appear to be interruptable, at least judging from the old implementation
	while(m_u.w != 0)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(223); return; }
state_223:
		write_memory(m_x.w++, m_q.r.a);
		if (UNEXPECTED(m_icount <= 0)) { push_state(224); return; }
state_224:
		m_u.w--;
	}
	return;

BSETW:
	// BSETW does not appear to be interruptable, at least judging from the old implementation
	while(m_u.w != 0)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(225); return; }
state_225:
		write_memory(m_x.w++, m_q.r.a);
		if (UNEXPECTED(m_icount <= 0)) { push_state(226); return; }
state_226:
		write_memory(m_x.w++, m_q.r.b);
		if (UNEXPECTED(m_icount <= 0)) { push_state(227); return; }
state_227:
		m_u.w--;
	}
	return;

DBJNZ:
	// not sure if this affects V?
	m_q.r.b = set_flags<uint8_t>(CC_NZV, m_q.r.b, 1, m_q.r.b - 1);
	eat(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(228); return; }
state_228:
	set_cond(cond_ne());
	goto BRANCH;

DXJNZ:
	// not sure if this affects V?
	m_x.w = set_flags<uint16_t>(CC_NZV, m_x.w, 1, m_x.w - 1);
	eat(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(229); return; }
state_229:
	set_cond(cond_ne());
	goto BRANCH;

LSRDI:
	// register addr.mode takes shift count from opcode operand, indexed addr.mode takes it from A
	m_bcount = is_register_addressing_mode() ? m_temp_im : m_q.r.a;

	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(230); return; }
state_230:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(231); return; }
state_231:

	while (m_bcount-- & 0xf)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(232); return; }
state_232:
		m_cc &= ~CC_C;
		m_cc |= (m_temp.w & 1) ? CC_C : 0;
		m_temp.w = set_flags<uint16_t>(CC_NZ, m_temp.w >> 1);
	}

	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(233); return; }
state_233:
	write_operand(1, m_temp.b.l);
	return;

ASLDI:
	// register addr.mode takes shift count from opcode operand, indexed addr.mode takes it from A
	m_bcount = is_register_addressing_mode() ? m_temp_im : m_q.r.a;

	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(234); return; }
state_234:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(235); return; }
state_235:

	while (m_bcount-- & 0xf)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(236); return; }
state_236:
		m_temp.w = set_flags<uint16_t>(CC_NZVC, m_temp.w, m_temp.w, m_temp.w << 1);
	}

	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(237); return; }
state_237:
	write_operand(1, m_temp.b.l);
	return;

ASRDI:
	// register addr.mode takes shift count from opcode operand, indexed addr.mode takes it from A
	m_bcount = is_register_addressing_mode() ? m_temp_im : m_q.r.a;

	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(238); return; }
state_238:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(239); return; }
state_239:

	while (m_bcount-- & 0xf)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(240); return; }
state_240:
		m_cc &= ~CC_C;
		m_cc |= (m_temp.w & 1) ? CC_C : 0;
		m_temp.w = set_flags<uint16_t>(CC_NZ, ((int16_t) m_temp.w) >> 1);
	}

	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(241); return; }
state_241:
	write_operand(1, m_temp.b.l);
	return;

ROLDI:
	// register addr.mode takes shift count from opcode operand, indexed addr.mode takes it from A
	m_bcount = is_register_addressing_mode() ? m_temp_im : m_q.r.a;

	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(242); return; }
state_242:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(243); return; }
state_243:

	while (m_bcount-- & 0xf)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(244); return; }
state_244:
		m_temp.w = set_flags<uint16_t>(CC_NZV, rotate_left(m_temp.w));
	}

	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(245); return; }
state_245:
	write_operand(1, m_temp.b.l);
	return;

RORDI:
	// register addr.mode takes shift count from opcode operand, indexed addr.mode takes it from A
	m_bcount = is_register_addressing_mode() ? m_temp_im : m_q.r.a;

	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(246); return; }
state_246:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(247); return; }
state_247:

	while (m_bcount-- & 0xf)
	{
		eat(1);
		if (UNEXPECTED(m_icount <= 0)) { push_state(248); return; }
state_248:
		m_temp.w = set_flags<uint16_t>(CC_NZ, rotate_right(m_temp.w));
	}

	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(249); return; }
state_249:
	write_operand(1, m_temp.b.l);
	return;

ABS8:
	m_temp.b.l = read_operand();
	if (UNEXPECTED(m_icount <= 0)) { push_state(250); return; }
state_250:
	m_temp.b.l = set_flags<uint8_t>(CC_NZVC, 0, m_temp.b.l, ((int8_t) m_temp.b.l) >= 0 ? m_temp.b.l : -m_temp.b.l);
	write_operand(m_temp.b.l);
	return;

ABS16:
	m_temp.b.h = read_operand(0);
	if (UNEXPECTED(m_icount <= 0)) { push_state(251); return; }
state_251:
	m_temp.b.l = read_operand(1);
	if (UNEXPECTED(m_icount <= 0)) { push_state(252); return; }
state_252:
	m_temp.w = set_flags<uint16_t>(CC_NZVC, 0, m_temp.w, ((int16_t) m_temp.w) >= 0 ? m_temp.w : -m_temp.w);
	write_operand(0, m_temp.b.h);
	if (UNEXPECTED(m_icount <= 0)) { push_state(253); return; }
state_253:
	write_operand(1, m_temp.b.l);
	return;

LMUL:
	lmul();
	eat(21);
	return;

DIVX:
	divx();
	eat(10);
	return;

ILLEGAL:
	log_illegal();
	return;

