void m65ce02_device::adc_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_Y;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_Y;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_imm_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	do_adc(m_TMP);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_imm_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	do_adc(m_TMP);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::adc_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::adc_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_adc(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_Y;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_Y;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::and_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::and_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_A &= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asl_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_asl(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asl_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_asl(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asl_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_asl(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asl_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_asl(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asl_ce_acc_full()
{
	m_A = do_asl(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asl_ce_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = do_asl(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asl_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_asl(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asl_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_asl(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asl_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_asl(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asl_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_asl(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asr_acc_full()
{
	m_A = do_asr(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asr_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = do_asr(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asr_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_asr(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asr_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_asr(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asr_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_asr(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asr_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_asr(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::asw_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP3 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP3 = set_h(m_TMP3, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_P &= ~(F_C|F_N|F_Z);
	if(m_TMP3 & 0x8000)
		m_P |= F_C;
	m_TMP3 <<= 1;
	if(!m_TMP3)
		m_P |= F_Z;
	else if(m_TMP3 & 0x8000)
		m_P |= F_N;
	write(m_TMP, m_TMP3);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	write(m_TMP, m_TMP3 >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_end();
}

void m65ce02_device::asw_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP3 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP3 = set_h(m_TMP3, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_P &= ~(F_C|F_N|F_Z);
	if(m_TMP3 & 0x8000)
		m_P |= F_C;
	m_TMP3 <<= 1;
	if(!m_TMP3)
		m_P |= F_Z;
	else if(m_TMP3 & 0x8000)
		m_P |= F_N;
	[[fallthrough]];
case 9:
	write(m_TMP, m_TMP3);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	[[fallthrough]];
case 11:
	write(m_TMP, m_TMP3 >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_start();
	[[fallthrough]];
case 13:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::aug_iw3_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_PC++;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::aug_iw3_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_PC++;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bbr_ce_zpb_full()
{
	// Access pattern uncertain
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_PC++;
	if(!(m_TMP2 & (1 << ((m_inst_state >> 4) & 7))))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bbr_ce_zpb_partial()
{
	switch(m_inst_substate) {
case 0:
	// Access pattern uncertain
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	[[fallthrough]];
case 5:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_PC++;
	if(!(m_TMP2 & (1 << ((m_inst_state >> 4) & 7))))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bbs_ce_zpb_full()
{
	// Access pattern uncertain
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_PC++;
	if(m_TMP2 & (1 << ((m_inst_state >> 4) & 7)))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bbs_ce_zpb_partial()
{
	switch(m_inst_substate) {
case 0:
	// Access pattern uncertain
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	[[fallthrough]];
case 5:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_PC++;
	if(m_TMP2 & (1 << ((m_inst_state >> 4) & 7)))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bcc_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(!(m_P & F_C))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bcc_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(!(m_P & F_C))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bcc_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(!(m_P & F_C))
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bcc_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(!(m_P & F_C))
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bcs_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(m_P & F_C)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bcs_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(m_P & F_C)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bcs_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(m_P & F_C)
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bcs_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(m_P & F_C)
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::beq_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(m_P & F_Z)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::beq_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(m_P & F_Z)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::beq_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(m_P & F_Z)
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::beq_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(m_P & F_Z)
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bit_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_bit(m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bit_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_bit(m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bit_ce_imm_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	do_bit(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bit_ce_imm_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	do_bit(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bit_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_bit(m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bit_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_bit(m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bit_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_bit(m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bit_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_bit(m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bmi_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(m_P & F_N)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bmi_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(m_P & F_N)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bmi_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(m_P & F_N)
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bmi_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(m_P & F_N)
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bne_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(!(m_P & F_Z))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bne_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(!(m_P & F_Z))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bne_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(!(m_P & F_Z))
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bne_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(!(m_P & F_Z))
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bpl_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(!(m_P & F_N))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bpl_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(!(m_P & F_N))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bpl_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(!(m_P & F_N))
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bpl_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(!(m_P & F_N))
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bra_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bra_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bra_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC += m_TMP;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bra_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC += m_TMP;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::brk_ce_imp_full()
{
	if(m_irq_taken) {
		read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	} else {
		read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
		m_PC++;
	}
	write(m_SP, m_PC >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_irq_taken || m_nmi_pending ? m_P & ~F_B : m_P);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	dec_SP_ce();
	if(m_nmi_pending) {
		m_PC = read_arg(0xfffa);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
		m_PC = set_h(m_PC, read_arg(0xfffb));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
		m_nmi_pending = false;
	} else {
		m_PC = read_arg(0xfffe);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 15;
		} else
			m_inst_substate = 16;
		return;
	}
		m_PC = set_h(m_PC, read_arg(0xffff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 17;
		} else
			m_inst_substate = 18;
		return;
	}
	}
	m_irq_taken = false;
	m_P = (m_P | F_I) & ~F_D; // Do *not* move after the prefetch
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 19;
		} else
			m_inst_substate = 20;
		return;
	}
	prefetch_end();
	m_inst_state = -1;
}

void m65ce02_device::brk_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	if(m_irq_taken) {
	[[fallthrough]];
case 1:
		read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	} else {
	[[fallthrough]];
case 3:
		read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
		m_PC++;
	}
	[[fallthrough]];
case 5:
	write(m_SP, m_PC >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	dec_SP_ce();
	[[fallthrough]];
case 7:
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	dec_SP_ce();
	[[fallthrough]];
case 9:
	write(m_SP, m_irq_taken || m_nmi_pending ? m_P & ~F_B : m_P);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	dec_SP_ce();
	if(m_nmi_pending) {
	[[fallthrough]];
case 11:
		m_PC = read_arg(0xfffa);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	[[fallthrough]];
case 13:
		m_PC = set_h(m_PC, read_arg(0xfffb));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
		m_nmi_pending = false;
	} else {
	[[fallthrough]];
case 15:
		m_PC = read_arg(0xfffe);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 15;
		} else
			m_inst_substate = 16;
		return;
	}
	[[fallthrough]];
case 16:;
	[[fallthrough]];
case 17:
		m_PC = set_h(m_PC, read_arg(0xffff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 17;
		} else
			m_inst_substate = 18;
		return;
	}
	[[fallthrough]];
case 18:;
	}
	m_irq_taken = false;
	m_P = (m_P | F_I) & ~F_D; // Do *not* move after the prefetch
	prefetch_start();
	[[fallthrough]];
case 19:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 19;
		} else
			m_inst_substate = 20;
		return;
	}
	[[fallthrough]];
case 20:;
	prefetch_end();
	m_inst_state = -1;
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bsr_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP_ce();
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_PC++;
	m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bsr_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	[[fallthrough]];
case 5:
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	dec_SP_ce();
	[[fallthrough]];
case 7:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_PC++;
	m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bvc_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(!(m_P & F_V))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bvc_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(!(m_P & F_V))
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bvc_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(!(m_P & F_V))
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bvc_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(!(m_P & F_V))
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bvs_ce_rel_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(m_P & F_V)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bvs_ce_rel_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(m_P & F_V)
		m_PC += int8_t(m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::bvs_rw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(m_P & F_V)
		m_PC += m_TMP-1;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::bvs_rw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(m_P & F_V)
		m_PC += m_TMP-1;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::clc_ce_imp_full()
{
	m_P &= ~F_C;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::clc_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_P &= ~F_C;
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cld_ce_imp_full()
{
	m_P &= ~F_D;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cld_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_P &= ~F_D;
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cle_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_P &= ~F_E;
	logerror("CLE\n");
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cle_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_P &= ~F_E;
	logerror("CLE\n");
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cli_ce_imp_full()
{
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
	m_P &= ~F_I; // Do *not* move it before the prefetch
}

void m65ce02_device::cli_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	m_P &= ~F_I; // Do *not* move it before the prefetch
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::clv_ce_imp_full()
{
	m_P &= ~F_V;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::clv_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_P &= ~F_V;
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_Y;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_Y;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cmp_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cmp_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_cmp(m_A, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cpx_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_cmp(m_X, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cpx_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_cmp(m_X, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cpy_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_cmp(m_Y, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cpy_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_cmp(m_Y, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cpz_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_cmp(m_Z, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cpz_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_cmp(m_Z, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cpz_imm_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	do_cmp(m_Z, m_TMP);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cpz_imm_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	do_cmp(m_Z, m_TMP);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::cpz_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_cmp(m_Z, m_TMP2);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::cpz_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_cmp(m_Z, m_TMP2);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dec_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2--;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dec_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2--;
	set_nz(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dec_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2--;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dec_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2--;
	set_nz(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dec_ce_acc_full()
{
	m_A--;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dec_ce_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A--;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dec_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2--;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dec_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2--;
	set_nz(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dec_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2--;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dec_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2--;
	set_nz(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dew_zpg_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_P &= ~(F_N|F_Z);
	m_TMP--;
	if(!m_TMP)
		m_P |= F_Z;
	else if(m_TMP & 0x8000)
		m_P |= F_N;
	m_TMP2--;
	write(m_B|m_TMP2, m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_TMP2++;
	write(m_B|m_TMP2, m_TMP >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dew_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_P &= ~(F_N|F_Z);
	m_TMP--;
	if(!m_TMP)
		m_P |= F_Z;
	else if(m_TMP & 0x8000)
		m_P |= F_N;
	m_TMP2--;
	[[fallthrough]];
case 7:
	write(m_B|m_TMP2, m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_TMP2++;
	[[fallthrough]];
case 9:
	write(m_B|m_TMP2, m_TMP >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_start();
	[[fallthrough]];
case 11:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dex_ce_imp_full()
{
	m_X--;
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dex_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_X--;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dey_ce_imp_full()
{
	m_Y--;
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dey_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Y--;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::dez_imp_full()
{
	m_Z--;
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::dez_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Z--;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_Y;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_Y;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::eor_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::eor_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_A ^= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inc_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2++;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inc_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2++;
	set_nz(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inc_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2++;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inc_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2++;
	set_nz(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inc_ce_acc_full()
{
	m_A++;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inc_ce_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A++;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inc_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inc_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	set_nz(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inc_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	set_nz(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inc_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	set_nz(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inw_zpg_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_P &= ~(F_N|F_Z);
	m_TMP++;
	if(!m_TMP)
		m_P |= F_Z;
	else if(m_TMP & 0x8000)
		m_P |= F_N;
	m_TMP2--;
	write(m_B|m_TMP2, m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_TMP2++;
	write(m_B|m_TMP2, m_TMP >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inw_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_P &= ~(F_N|F_Z);
	m_TMP++;
	if(!m_TMP)
		m_P |= F_Z;
	else if(m_TMP & 0x8000)
		m_P |= F_N;
	m_TMP2--;
	[[fallthrough]];
case 7:
	write(m_B|m_TMP2, m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_TMP2++;
	[[fallthrough]];
case 9:
	write(m_B|m_TMP2, m_TMP >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_start();
	[[fallthrough]];
case 11:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inx_ce_imp_full()
{
	m_X++;
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inx_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_X++;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::iny_ce_imp_full()
{
	m_Y++;
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::iny_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Y++;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::inz_imp_full()
{
	m_Z++;
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::inz_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Z++;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::jmp_ce_iax_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::jmp_ce_iax_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::jmp_ce_ind_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::jmp_ce_ind_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::jsr_ce_adr_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP_ce();
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_PC++;
	m_PC = m_TMP;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::jsr_ce_adr_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	[[fallthrough]];
case 5:
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	dec_SP_ce();
	[[fallthrough]];
case 7:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_PC++;
	m_PC = m_TMP;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::jsr_iax_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP_ce();
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_PC++;
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	m_PC += m_X;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_end();
}

void m65ce02_device::jsr_iax_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	[[fallthrough]];
case 5:
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	dec_SP_ce();
	[[fallthrough]];
case 7:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_PC++;
	[[fallthrough]];
case 9:
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	[[fallthrough]];
case 11:
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	m_PC += m_X;
	prefetch_start();
	[[fallthrough]];
case 13:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::jsr_ind_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP_ce();
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_PC++;
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_end();
}

void m65ce02_device::jsr_ind_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	[[fallthrough]];
case 5:
	write(m_SP, m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	dec_SP_ce();
	[[fallthrough]];
case 7:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_PC++;
	[[fallthrough]];
case 9:
	m_PC = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	[[fallthrough]];
case 11:
	m_PC = set_h(m_PC, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_start();
	[[fallthrough]];
case 13:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_A = read(m_TMP + m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_A = read(m_TMP + m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_A = read(m_TMP + m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_A = read(m_TMP + m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_A = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_A = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_A = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_isy_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(m_P & F_E)
		m_TMP = set_l(m_SP, m_SP+m_TMP);
	else
		m_TMP = m_SP + m_TMP;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP++;
	m_TMP = m_TMP2 | (read(m_TMP) << 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_isy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(m_P & F_E)
		m_TMP = set_l(m_SP, m_SP+m_TMP);
	else
		m_TMP = m_SP + m_TMP;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP++;
	[[fallthrough]];
case 7:
	m_TMP = m_TMP2 | (read(m_TMP) << 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	[[fallthrough]];
case 9:
	m_A = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 11:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_A = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_A = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lda_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_A = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lda_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_A = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldx_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_X = read(m_TMP + m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldx_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_X = read(m_TMP + m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldx_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_X = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldx_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_X = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldx_ce_zpy_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_X = read(m_B|uint8_t(m_TMP+m_Y));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldx_ce_zpy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_X = read(m_B|uint8_t(m_TMP+m_Y));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldy_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_Y = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldy_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_Y = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldy_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_Y = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldy_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_Y = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldy_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_Y = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldy_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_Y = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldz_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_Z = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldz_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_Z = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldz_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_Z = read(m_TMP + m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldz_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_Z = read(m_TMP + m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ldz_imm_full()
{
	m_Z = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ldz_imm_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_Z = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lsr_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_lsr(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lsr_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_lsr(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lsr_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_TMP2 = do_lsr(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lsr_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP += m_X;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_TMP2 = do_lsr(m_TMP2);
	[[fallthrough]];
case 9:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_start();
	[[fallthrough]];
case 11:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lsr_ce_acc_full()
{
	m_A = do_lsr(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lsr_ce_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = do_lsr(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lsr_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_lsr(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lsr_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_lsr(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::lsr_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_lsr(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::lsr_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_lsr(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::neg_acc_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_A = -m_A;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::neg_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_A = -m_A;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_Y;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_Y;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ora_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ora_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_A |= m_TMP2;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::pha_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	write(m_SP, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::pha_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	write(m_SP, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::php_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	write(m_SP, m_P);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::php_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	write(m_SP, m_P);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::phw_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP3 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP3 = set_h(m_TMP3, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	write(m_SP, m_TMP3);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_TMP3 >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_end();
}

void m65ce02_device::phw_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP3 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP3 = set_h(m_TMP3, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	[[fallthrough]];
case 9:
	write(m_SP, m_TMP3);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	dec_SP_ce();
	[[fallthrough]];
case 11:
	write(m_SP, m_TMP3 >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 13:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::phw_iw2_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_SP, m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP_ce();
	write(m_SP, m_TMP >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::phw_iw2_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_SP, m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	dec_SP_ce();
	[[fallthrough]];
case 7:
	write(m_SP, m_TMP >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::phx_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	write(m_SP, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::phx_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	write(m_SP, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::phy_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	write(m_SP, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::phy_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	write(m_SP, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::phz_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	write(m_SP, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP_ce();
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::phz_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	write(m_SP, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	dec_SP_ce();
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::pla_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_A = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::pla_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_A = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::plp_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_TMP = read(m_SP) | F_B;
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
	m_P = m_TMP; // Do *not* move it before the prefetch
}

void m65ce02_device::plp_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_TMP = read(m_SP) | F_B;
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	m_P = m_TMP; // Do *not* move it before the prefetch
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::plx_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_X = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::plx_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_X = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ply_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_Y = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ply_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_Y = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::plz_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_Z = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::plz_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_Z = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rmb_ce_bzp_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 &= ~(1 << ((m_inst_state >> 4) & 7));
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rmb_ce_bzp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 &= ~(1 << ((m_inst_state >> 4) & 7));
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rol_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_rol(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rol_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_rol(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rol_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_rol(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rol_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_rol(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rol_ce_acc_full()
{
	m_A = do_rol(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rol_ce_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = do_rol(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rol_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_rol(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rol_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_rol(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rol_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_rol(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rol_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_rol(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ror_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_ror(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ror_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_ror(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ror_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = do_ror(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ror_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP2 = do_ror(m_TMP2);
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ror_ce_acc_full()
{
	m_A = do_ror(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ror_ce_acc_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = do_ror(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ror_ce_zpg_full()
{
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_ror(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ror_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = m_B|read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_ror(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::ror_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = do_ror(m_TMP2);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::ror_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP = m_B|uint8_t(m_TMP+m_X);
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 = do_ror(m_TMP2);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::row_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP3 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP3 = set_h(m_TMP3, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_TMP2 = m_P;
	m_P &= ~(F_C|F_N|F_Z);
	if(m_TMP3 & 0x8000)
		m_P |= F_C;
	m_TMP3 <<= 1;
	if(m_TMP2 & F_C)
		m_TMP3 |= 0x0001;
	if(!m_TMP3)
		m_P |= F_Z;
	else if(m_TMP3 & 0x8000)
		m_P |= F_N;
	write(m_TMP, m_TMP3);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	write(m_TMP, m_TMP3 >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_end();
}

void m65ce02_device::row_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP3 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP3 = set_h(m_TMP3, read(m_TMP+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	m_TMP2 = m_P;
	m_P &= ~(F_C|F_N|F_Z);
	if(m_TMP3 & 0x8000)
		m_P |= F_C;
	m_TMP3 <<= 1;
	if(m_TMP2 & F_C)
		m_TMP3 |= 0x0001;
	if(!m_TMP3)
		m_P |= F_Z;
	else if(m_TMP3 & 0x8000)
		m_P |= F_N;
	[[fallthrough]];
case 9:
	write(m_TMP, m_TMP3);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	[[fallthrough]];
case 11:
	write(m_TMP, m_TMP3 >> 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_start();
	[[fallthrough]];
case 13:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rti_ce_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_P = read(m_SP) | F_B;
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	inc_SP_ce();
	m_PC = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	inc_SP_ce();
	m_PC = set_h(m_PC, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rti_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_P = read(m_SP) | F_B;
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	inc_SP_ce();
	[[fallthrough]];
case 5:
	m_PC = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	inc_SP_ce();
	[[fallthrough]];
case 7:
	m_PC = set_h(m_PC, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rtn_imm_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	if(m_P & F_E)
		m_SP = set_l(m_SP, m_SP+m_TMP);
	else
		m_SP += m_TMP;
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	inc_SP();
	m_PC = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	inc_SP();
	m_PC = set_h(m_PC, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	m_PC++;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rtn_imm_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	if(m_P & F_E)
		m_SP = set_l(m_SP, m_SP+m_TMP);
	else
		m_SP += m_TMP;
	[[fallthrough]];
case 3:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	[[fallthrough]];
case 5:
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	inc_SP();
	[[fallthrough]];
case 7:
	m_PC = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	inc_SP();
	[[fallthrough]];
case 9:
	m_PC = set_h(m_PC, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	[[fallthrough]];
case 11:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	m_PC++;
	prefetch_start();
	[[fallthrough]];
case 13:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	[[fallthrough]];
case 14:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::rts_ce_imp_full()
{
	inc_SP_ce();
	m_PC = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	inc_SP_ce();
	m_PC = set_h(m_PC, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_PC++;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::rts_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	inc_SP_ce();
	[[fallthrough]];
case 1:
	m_PC = read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	inc_SP_ce();
	[[fallthrough]];
case 3:
	m_PC = set_h(m_PC, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	[[fallthrough]];
case 5:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_PC++;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_X;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_X;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP += m_Y;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	m_TMP += m_Y;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	m_TMP2 = read(m_TMP+m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_imm_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	do_sbc_c(m_TMP);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_imm_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	do_sbc_c(m_TMP);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_B|m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sbc_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sbc_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_B|uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	do_sbc_c(m_TMP2);
	if(m_P & F_D)
		set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sec_ce_imp_full()
{
	m_P |= F_C;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sec_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_P |= F_C;
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sed_ce_imp_full()
{
	m_P |= F_D;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sed_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_P |= F_D;
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::see_imp_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_P |= F_E;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_end();
}

void m65ce02_device::see_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_P |= F_E;
	prefetch_start();
	[[fallthrough]];
case 3:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sei_ce_imp_full()
{
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
	m_P |= F_I; // Do *not* move it before the prefetch
}

void m65ce02_device::sei_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	m_P |= F_I; // Do *not* move it before the prefetch
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::smb_ce_bzp_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2 |= 1 << ((m_inst_state >> 4) & 7);
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::smb_ce_bzp_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2 |= 1 << ((m_inst_state >> 4) & 7);
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_TMP+m_X, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_TMP+m_X, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_ce_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_TMP+m_Y, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_ce_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_TMP+m_Y, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_ce_idx_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 += m_X;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	write(m_TMP, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_ce_idx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	m_TMP2 += m_X;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	write(m_TMP, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_ce_idy_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	write(m_TMP+m_Y, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_ce_idy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	write(m_TMP+m_Y, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_idz_full()
{
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP2++;
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	write(m_TMP+m_Z, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_idz_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP2 = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = read(m_B|m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_TMP2++;
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read(m_B|m_TMP2));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	[[fallthrough]];
case 7:
	write(m_TMP+m_Z, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_isy_full()
{
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	if(m_P & F_E)
		m_TMP = set_l(m_SP, m_SP+m_TMP);
	else
		m_TMP = m_SP + m_TMP;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_TMP++;
	m_TMP = m_TMP2 | (read(m_TMP) << 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	write(m_TMP+m_Y, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_isy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	[[fallthrough]];
case 3:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	if(m_P & F_E)
		m_TMP = set_l(m_SP, m_SP+m_TMP);
	else
		m_TMP = m_SP + m_TMP;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	m_TMP++;
	[[fallthrough]];
case 7:
	m_TMP = m_TMP2 | (read(m_TMP) << 8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	[[fallthrough]];
case 9:
	write(m_TMP+m_Y, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_start();
	[[fallthrough]];
case 11:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	[[fallthrough]];
case 12:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|m_TMP, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|m_TMP, m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sta_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|uint8_t(m_TMP+m_X), m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sta_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|uint8_t(m_TMP+m_X), m_A);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stx_aby_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_TMP+m_Y, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stx_aby_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_TMP+m_Y, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stx_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|m_TMP, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stx_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|m_TMP, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stx_ce_zpy_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|uint8_t(m_TMP+m_Y), m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stx_ce_zpy_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|uint8_t(m_TMP+m_Y), m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sty_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_TMP+m_X, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sty_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_TMP+m_X, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sty_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|m_TMP, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sty_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|m_TMP, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::sty_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|uint8_t(m_TMP+m_X), m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::sty_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|uint8_t(m_TMP+m_X), m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stz_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_TMP, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stz_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_TMP, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stz_ce_abx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	write(m_TMP+m_X, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stz_ce_abx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	write(m_TMP+m_X, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stz_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|m_TMP, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stz_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|m_TMP, m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::stz_ce_zpx_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	write(m_B|uint8_t(m_TMP+m_X), m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_end();
}

void m65ce02_device::stz_ce_zpx_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	write(m_B|uint8_t(m_TMP+m_X), m_Z);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	prefetch_start();
	[[fallthrough]];
case 5:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tab_imp_full()
{
	m_B = m_A << 8;
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tab_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_B = m_A << 8;
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tax_ce_imp_full()
{
	m_X = m_A;
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tax_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_X = m_A;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tay_ce_imp_full()
{
	m_Y = m_A;
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tay_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Y = m_A;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::taz_imp_full()
{
	m_Z = m_A;
	set_nz(m_Z);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::taz_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Z = m_A;
	set_nz(m_Z);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tba_imp_full()
{
	m_A = m_B >> 8;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tba_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = m_B >> 8;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::trb_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 &= ~m_A;
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::trb_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 &= ~m_A;
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::trb_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 &= ~m_A;
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::trb_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 &= ~m_A;
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tsb_ce_aba_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 |= m_A;
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tsb_ce_aba_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP = set_h(m_TMP, read_pc());
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	m_PC++;
	[[fallthrough]];
case 5:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 |= m_A;
	[[fallthrough]];
case 7:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_start();
	[[fallthrough]];
case 9:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	[[fallthrough]];
case 10:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tsb_ce_zpg_full()
{
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_PC++;
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 |= m_A;
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tsb_ce_zpg_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	m_PC++;
	[[fallthrough]];
case 3:
	m_TMP2 = read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	[[fallthrough]];
case 4:;
	if(m_A & m_TMP2)
		m_P &= ~F_Z;
	else
		m_P |= F_Z;
	m_TMP2 |= m_A;
	[[fallthrough]];
case 5:
	write(m_TMP, m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	[[fallthrough]];
case 6:;
	prefetch_start();
	[[fallthrough]];
case 7:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	[[fallthrough]];
case 8:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tsx_ce_imp_full()
{
	m_X = m_SP;
	set_nz(m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tsx_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_X = m_SP;
	set_nz(m_X);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tsy_imp_full()
{
	m_Y = m_SP >> 8;
	set_nz(m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tsy_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_Y = m_SP >> 8;
	set_nz(m_Y);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::txa_ce_imp_full()
{
	m_A = m_X;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::txa_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = m_X;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::txs_ce_imp_full()
{
	m_SP = set_l(m_SP, m_X);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end_noirq();
}

void m65ce02_device::txs_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_SP = set_l(m_SP, m_X);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end_noirq();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tys_imp_full()
{
	m_SP = set_h(m_SP, m_Y);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tys_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_SP = set_h(m_SP, m_Y);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tya_ce_imp_full()
{
	m_A = m_Y;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tya_ce_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = m_Y;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void m65ce02_device::tza_imp_full()
{
	m_A = m_Z;
	set_nz(m_A);
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	prefetch_end();
}

void m65ce02_device::tza_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	m_A = m_Z;
	set_nz(m_A);
	prefetch_start();
	[[fallthrough]];
case 1:
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	[[fallthrough]];
case 2:;
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}



void m65ce02_device::do_exec_full()
{
	switch(m_inst_state) {

	case 0x00: brk_ce_imp_full(); break;
	case 0x01: ora_ce_idx_full(); break;
	case 0x02: cle_imp_full(); break;
	case 0x03: see_imp_full(); break;
	case 0x04: tsb_ce_zpg_full(); break;
	case 0x05: ora_ce_zpg_full(); break;
	case 0x06: asl_ce_zpg_full(); break;
	case 0x07: rmb_ce_bzp_full(); break;
	case 0x08: php_ce_imp_full(); break;
	case 0x09: ora_imm_full(); break;
	case 0x0a: asl_ce_acc_full(); break;
	case 0x0b: tsy_imp_full(); break;
	case 0x0c: tsb_ce_aba_full(); break;
	case 0x0d: ora_aba_full(); break;
	case 0x0e: asl_ce_aba_full(); break;
	case 0x0f: bbr_ce_zpb_full(); break;
	case 0x10: bpl_ce_rel_full(); break;
	case 0x11: ora_ce_idy_full(); break;
	case 0x12: ora_idz_full(); break;
	case 0x13: bpl_rw2_full(); break;
	case 0x14: trb_ce_zpg_full(); break;
	case 0x15: ora_ce_zpx_full(); break;
	case 0x16: asl_ce_zpx_full(); break;
	case 0x17: rmb_ce_bzp_full(); break;
	case 0x18: clc_ce_imp_full(); break;
	case 0x19: ora_ce_aby_full(); break;
	case 0x1a: inc_ce_acc_full(); break;
	case 0x1b: inz_imp_full(); break;
	case 0x1c: trb_ce_aba_full(); break;
	case 0x1d: ora_ce_abx_full(); break;
	case 0x1e: asl_ce_abx_full(); break;
	case 0x1f: bbr_ce_zpb_full(); break;
	case 0x20: jsr_ce_adr_full(); break;
	case 0x21: and_ce_idx_full(); break;
	case 0x22: jsr_ind_full(); break;
	case 0x23: jsr_iax_full(); break;
	case 0x24: bit_ce_zpg_full(); break;
	case 0x25: and_ce_zpg_full(); break;
	case 0x26: rol_ce_zpg_full(); break;
	case 0x27: rmb_ce_bzp_full(); break;
	case 0x28: plp_ce_imp_full(); break;
	case 0x29: and_imm_full(); break;
	case 0x2a: rol_ce_acc_full(); break;
	case 0x2b: tys_imp_full(); break;
	case 0x2c: bit_aba_full(); break;
	case 0x2d: and_aba_full(); break;
	case 0x2e: rol_ce_aba_full(); break;
	case 0x2f: bbr_ce_zpb_full(); break;
	case 0x30: bmi_ce_rel_full(); break;
	case 0x31: and_ce_idy_full(); break;
	case 0x32: and_idz_full(); break;
	case 0x33: bmi_rw2_full(); break;
	case 0x34: bit_ce_zpx_full(); break;
	case 0x35: and_ce_zpx_full(); break;
	case 0x36: rol_ce_zpx_full(); break;
	case 0x37: rmb_ce_bzp_full(); break;
	case 0x38: sec_ce_imp_full(); break;
	case 0x39: and_ce_aby_full(); break;
	case 0x3a: dec_ce_acc_full(); break;
	case 0x3b: dez_imp_full(); break;
	case 0x3c: bit_ce_abx_full(); break;
	case 0x3d: and_ce_abx_full(); break;
	case 0x3e: rol_ce_abx_full(); break;
	case 0x3f: bbr_ce_zpb_full(); break;
	case 0x40: rti_ce_imp_full(); break;
	case 0x41: eor_ce_idx_full(); break;
	case 0x42: neg_acc_full(); break;
	case 0x43: asr_acc_full(); break;
	case 0x44: asr_zpg_full(); break;
	case 0x45: eor_ce_zpg_full(); break;
	case 0x46: lsr_ce_zpg_full(); break;
	case 0x47: rmb_ce_bzp_full(); break;
	case 0x48: pha_ce_imp_full(); break;
	case 0x49: eor_imm_full(); break;
	case 0x4a: lsr_ce_acc_full(); break;
	case 0x4b: taz_imp_full(); break;
	case 0x4c: jmp_adr_full(); break;
	case 0x4d: eor_aba_full(); break;
	case 0x4e: lsr_ce_aba_full(); break;
	case 0x4f: bbr_ce_zpb_full(); break;
	case 0x50: bvc_ce_rel_full(); break;
	case 0x51: eor_ce_idy_full(); break;
	case 0x52: eor_idz_full(); break;
	case 0x53: bvc_rw2_full(); break;
	case 0x54: asr_zpx_full(); break;
	case 0x55: eor_ce_zpx_full(); break;
	case 0x56: lsr_ce_zpx_full(); break;
	case 0x57: rmb_ce_bzp_full(); break;
	case 0x58: cli_ce_imp_full(); break;
	case 0x59: eor_ce_aby_full(); break;
	case 0x5a: phy_ce_imp_full(); break;
	case 0x5b: tab_imp_full(); break;
	case 0x5c: aug_iw3_full(); break;
	case 0x5d: eor_ce_abx_full(); break;
	case 0x5e: lsr_ce_abx_full(); break;
	case 0x5f: bbr_ce_zpb_full(); break;
	case 0x60: rts_ce_imp_full(); break;
	case 0x61: adc_ce_idx_full(); break;
	case 0x62: rtn_imm_full(); break;
	case 0x63: bsr_rw2_full(); break;
	case 0x64: stz_ce_zpg_full(); break;
	case 0x65: adc_ce_zpg_full(); break;
	case 0x66: ror_ce_zpg_full(); break;
	case 0x67: rmb_ce_bzp_full(); break;
	case 0x68: pla_ce_imp_full(); break;
	case 0x69: adc_ce_imm_full(); break;
	case 0x6a: ror_ce_acc_full(); break;
	case 0x6b: tza_imp_full(); break;
	case 0x6c: jmp_ce_ind_full(); break;
	case 0x6d: adc_ce_aba_full(); break;
	case 0x6e: ror_ce_aba_full(); break;
	case 0x6f: bbr_ce_zpb_full(); break;
	case 0x70: bvs_ce_rel_full(); break;
	case 0x71: adc_ce_idy_full(); break;
	case 0x72: adc_idz_full(); break;
	case 0x73: bvs_rw2_full(); break;
	case 0x74: stz_ce_zpx_full(); break;
	case 0x75: adc_ce_zpx_full(); break;
	case 0x76: ror_ce_zpx_full(); break;
	case 0x77: rmb_ce_bzp_full(); break;
	case 0x78: sei_ce_imp_full(); break;
	case 0x79: adc_ce_aby_full(); break;
	case 0x7a: ply_ce_imp_full(); break;
	case 0x7b: tba_imp_full(); break;
	case 0x7c: jmp_ce_iax_full(); break;
	case 0x7d: adc_ce_abx_full(); break;
	case 0x7e: ror_ce_abx_full(); break;
	case 0x7f: bbr_ce_zpb_full(); break;
	case 0x80: bra_ce_rel_full(); break;
	case 0x81: sta_ce_idx_full(); break;
	case 0x82: sta_isy_full(); break;
	case 0x83: bra_rw2_full(); break;
	case 0x84: sty_ce_zpg_full(); break;
	case 0x85: sta_ce_zpg_full(); break;
	case 0x86: stx_ce_zpg_full(); break;
	case 0x87: smb_ce_bzp_full(); break;
	case 0x88: dey_ce_imp_full(); break;
	case 0x89: bit_ce_imm_full(); break;
	case 0x8a: txa_ce_imp_full(); break;
	case 0x8b: sty_abx_full(); break;
	case 0x8c: sty_aba_full(); break;
	case 0x8d: sta_aba_full(); break;
	case 0x8e: stx_aba_full(); break;
	case 0x8f: bbs_ce_zpb_full(); break;
	case 0x90: bcc_ce_rel_full(); break;
	case 0x91: sta_ce_idy_full(); break;
	case 0x92: sta_idz_full(); break;
	case 0x93: bcc_rw2_full(); break;
	case 0x94: sty_ce_zpx_full(); break;
	case 0x95: sta_ce_zpx_full(); break;
	case 0x96: stx_ce_zpy_full(); break;
	case 0x97: smb_ce_bzp_full(); break;
	case 0x98: tya_ce_imp_full(); break;
	case 0x99: sta_ce_aby_full(); break;
	case 0x9a: txs_ce_imp_full(); break;
	case 0x9b: stx_aby_full(); break;
	case 0x9c: stz_ce_aba_full(); break;
	case 0x9d: sta_ce_abx_full(); break;
	case 0x9e: stz_ce_abx_full(); break;
	case 0x9f: bbs_ce_zpb_full(); break;
	case 0xa0: ldy_imm_full(); break;
	case 0xa1: lda_ce_idx_full(); break;
	case 0xa2: ldx_imm_full(); break;
	case 0xa3: ldz_imm_full(); break;
	case 0xa4: ldy_ce_zpg_full(); break;
	case 0xa5: lda_ce_zpg_full(); break;
	case 0xa6: ldx_ce_zpg_full(); break;
	case 0xa7: smb_ce_bzp_full(); break;
	case 0xa8: tay_ce_imp_full(); break;
	case 0xa9: lda_imm_full(); break;
	case 0xaa: tax_ce_imp_full(); break;
	case 0xab: ldz_aba_full(); break;
	case 0xac: ldy_aba_full(); break;
	case 0xad: lda_aba_full(); break;
	case 0xae: ldx_aba_full(); break;
	case 0xaf: bbs_ce_zpb_full(); break;
	case 0xb0: bcs_ce_rel_full(); break;
	case 0xb1: lda_ce_idy_full(); break;
	case 0xb2: lda_idz_full(); break;
	case 0xb3: bcs_rw2_full(); break;
	case 0xb4: ldy_ce_zpx_full(); break;
	case 0xb5: lda_ce_zpx_full(); break;
	case 0xb6: ldx_ce_zpy_full(); break;
	case 0xb7: smb_ce_bzp_full(); break;
	case 0xb8: clv_ce_imp_full(); break;
	case 0xb9: lda_ce_aby_full(); break;
	case 0xba: tsx_ce_imp_full(); break;
	case 0xbb: ldz_abx_full(); break;
	case 0xbc: ldy_ce_abx_full(); break;
	case 0xbd: lda_ce_abx_full(); break;
	case 0xbe: ldx_ce_aby_full(); break;
	case 0xbf: bbs_ce_zpb_full(); break;
	case 0xc0: cpy_imm_full(); break;
	case 0xc1: cmp_ce_idx_full(); break;
	case 0xc2: cpz_imm_full(); break;
	case 0xc3: dew_zpg_full(); break;
	case 0xc4: cpy_ce_zpg_full(); break;
	case 0xc5: cmp_ce_zpg_full(); break;
	case 0xc6: dec_ce_zpg_full(); break;
	case 0xc7: smb_ce_bzp_full(); break;
	case 0xc8: iny_ce_imp_full(); break;
	case 0xc9: cmp_imm_full(); break;
	case 0xca: dex_ce_imp_full(); break;
	case 0xcb: asw_aba_full(); break;
	case 0xcc: cpy_aba_full(); break;
	case 0xcd: cmp_aba_full(); break;
	case 0xce: dec_ce_aba_full(); break;
	case 0xcf: bbs_ce_zpb_full(); break;
	case 0xd0: bne_ce_rel_full(); break;
	case 0xd1: cmp_ce_idy_full(); break;
	case 0xd2: cmp_idz_full(); break;
	case 0xd3: bne_rw2_full(); break;
	case 0xd4: cpz_zpg_full(); break;
	case 0xd5: cmp_ce_zpx_full(); break;
	case 0xd6: dec_ce_zpx_full(); break;
	case 0xd7: smb_ce_bzp_full(); break;
	case 0xd8: cld_ce_imp_full(); break;
	case 0xd9: cmp_ce_aby_full(); break;
	case 0xda: phx_ce_imp_full(); break;
	case 0xdb: phz_imp_full(); break;
	case 0xdc: cpz_aba_full(); break;
	case 0xdd: cmp_ce_abx_full(); break;
	case 0xde: dec_ce_abx_full(); break;
	case 0xdf: bbs_ce_zpb_full(); break;
	case 0xe0: cpx_imm_full(); break;
	case 0xe1: sbc_ce_idx_full(); break;
	case 0xe2: lda_isy_full(); break;
	case 0xe3: inw_zpg_full(); break;
	case 0xe4: cpx_ce_zpg_full(); break;
	case 0xe5: sbc_ce_zpg_full(); break;
	case 0xe6: inc_ce_zpg_full(); break;
	case 0xe7: smb_ce_bzp_full(); break;
	case 0xe8: inx_ce_imp_full(); break;
	case 0xe9: sbc_ce_imm_full(); break;
	case 0xea: nop_c_imp_full(); break;
	case 0xeb: row_aba_full(); break;
	case 0xec: cpx_aba_full(); break;
	case 0xed: sbc_ce_aba_full(); break;
	case 0xee: inc_ce_aba_full(); break;
	case 0xef: bbs_ce_zpb_full(); break;
	case 0xf0: beq_ce_rel_full(); break;
	case 0xf1: sbc_ce_idy_full(); break;
	case 0xf2: sbc_idz_full(); break;
	case 0xf3: beq_rw2_full(); break;
	case 0xf4: phw_iw2_full(); break;
	case 0xf5: sbc_ce_zpx_full(); break;
	case 0xf6: inc_ce_zpx_full(); break;
	case 0xf7: smb_ce_bzp_full(); break;
	case 0xf8: sed_ce_imp_full(); break;
	case 0xf9: sbc_ce_aby_full(); break;
	case 0xfa: plx_ce_imp_full(); break;
	case 0xfb: plz_imp_full(); break;
	case 0xfc: phw_aba_full(); break;
	case 0xfd: sbc_ce_abx_full(); break;
	case 0xfe: inc_ce_abx_full(); break;
	case 0xff: bbs_ce_zpb_full(); break;
	case STATE_RESET: reset_c_full(); break;
	}
}

void m65ce02_device::do_exec_partial()
{
	switch(m_inst_state) {

	case 0x00: brk_ce_imp_partial(); break;
	case 0x01: ora_ce_idx_partial(); break;
	case 0x02: cle_imp_partial(); break;
	case 0x03: see_imp_partial(); break;
	case 0x04: tsb_ce_zpg_partial(); break;
	case 0x05: ora_ce_zpg_partial(); break;
	case 0x06: asl_ce_zpg_partial(); break;
	case 0x07: rmb_ce_bzp_partial(); break;
	case 0x08: php_ce_imp_partial(); break;
	case 0x09: ora_imm_partial(); break;
	case 0x0a: asl_ce_acc_partial(); break;
	case 0x0b: tsy_imp_partial(); break;
	case 0x0c: tsb_ce_aba_partial(); break;
	case 0x0d: ora_aba_partial(); break;
	case 0x0e: asl_ce_aba_partial(); break;
	case 0x0f: bbr_ce_zpb_partial(); break;
	case 0x10: bpl_ce_rel_partial(); break;
	case 0x11: ora_ce_idy_partial(); break;
	case 0x12: ora_idz_partial(); break;
	case 0x13: bpl_rw2_partial(); break;
	case 0x14: trb_ce_zpg_partial(); break;
	case 0x15: ora_ce_zpx_partial(); break;
	case 0x16: asl_ce_zpx_partial(); break;
	case 0x17: rmb_ce_bzp_partial(); break;
	case 0x18: clc_ce_imp_partial(); break;
	case 0x19: ora_ce_aby_partial(); break;
	case 0x1a: inc_ce_acc_partial(); break;
	case 0x1b: inz_imp_partial(); break;
	case 0x1c: trb_ce_aba_partial(); break;
	case 0x1d: ora_ce_abx_partial(); break;
	case 0x1e: asl_ce_abx_partial(); break;
	case 0x1f: bbr_ce_zpb_partial(); break;
	case 0x20: jsr_ce_adr_partial(); break;
	case 0x21: and_ce_idx_partial(); break;
	case 0x22: jsr_ind_partial(); break;
	case 0x23: jsr_iax_partial(); break;
	case 0x24: bit_ce_zpg_partial(); break;
	case 0x25: and_ce_zpg_partial(); break;
	case 0x26: rol_ce_zpg_partial(); break;
	case 0x27: rmb_ce_bzp_partial(); break;
	case 0x28: plp_ce_imp_partial(); break;
	case 0x29: and_imm_partial(); break;
	case 0x2a: rol_ce_acc_partial(); break;
	case 0x2b: tys_imp_partial(); break;
	case 0x2c: bit_aba_partial(); break;
	case 0x2d: and_aba_partial(); break;
	case 0x2e: rol_ce_aba_partial(); break;
	case 0x2f: bbr_ce_zpb_partial(); break;
	case 0x30: bmi_ce_rel_partial(); break;
	case 0x31: and_ce_idy_partial(); break;
	case 0x32: and_idz_partial(); break;
	case 0x33: bmi_rw2_partial(); break;
	case 0x34: bit_ce_zpx_partial(); break;
	case 0x35: and_ce_zpx_partial(); break;
	case 0x36: rol_ce_zpx_partial(); break;
	case 0x37: rmb_ce_bzp_partial(); break;
	case 0x38: sec_ce_imp_partial(); break;
	case 0x39: and_ce_aby_partial(); break;
	case 0x3a: dec_ce_acc_partial(); break;
	case 0x3b: dez_imp_partial(); break;
	case 0x3c: bit_ce_abx_partial(); break;
	case 0x3d: and_ce_abx_partial(); break;
	case 0x3e: rol_ce_abx_partial(); break;
	case 0x3f: bbr_ce_zpb_partial(); break;
	case 0x40: rti_ce_imp_partial(); break;
	case 0x41: eor_ce_idx_partial(); break;
	case 0x42: neg_acc_partial(); break;
	case 0x43: asr_acc_partial(); break;
	case 0x44: asr_zpg_partial(); break;
	case 0x45: eor_ce_zpg_partial(); break;
	case 0x46: lsr_ce_zpg_partial(); break;
	case 0x47: rmb_ce_bzp_partial(); break;
	case 0x48: pha_ce_imp_partial(); break;
	case 0x49: eor_imm_partial(); break;
	case 0x4a: lsr_ce_acc_partial(); break;
	case 0x4b: taz_imp_partial(); break;
	case 0x4c: jmp_adr_partial(); break;
	case 0x4d: eor_aba_partial(); break;
	case 0x4e: lsr_ce_aba_partial(); break;
	case 0x4f: bbr_ce_zpb_partial(); break;
	case 0x50: bvc_ce_rel_partial(); break;
	case 0x51: eor_ce_idy_partial(); break;
	case 0x52: eor_idz_partial(); break;
	case 0x53: bvc_rw2_partial(); break;
	case 0x54: asr_zpx_partial(); break;
	case 0x55: eor_ce_zpx_partial(); break;
	case 0x56: lsr_ce_zpx_partial(); break;
	case 0x57: rmb_ce_bzp_partial(); break;
	case 0x58: cli_ce_imp_partial(); break;
	case 0x59: eor_ce_aby_partial(); break;
	case 0x5a: phy_ce_imp_partial(); break;
	case 0x5b: tab_imp_partial(); break;
	case 0x5c: aug_iw3_partial(); break;
	case 0x5d: eor_ce_abx_partial(); break;
	case 0x5e: lsr_ce_abx_partial(); break;
	case 0x5f: bbr_ce_zpb_partial(); break;
	case 0x60: rts_ce_imp_partial(); break;
	case 0x61: adc_ce_idx_partial(); break;
	case 0x62: rtn_imm_partial(); break;
	case 0x63: bsr_rw2_partial(); break;
	case 0x64: stz_ce_zpg_partial(); break;
	case 0x65: adc_ce_zpg_partial(); break;
	case 0x66: ror_ce_zpg_partial(); break;
	case 0x67: rmb_ce_bzp_partial(); break;
	case 0x68: pla_ce_imp_partial(); break;
	case 0x69: adc_ce_imm_partial(); break;
	case 0x6a: ror_ce_acc_partial(); break;
	case 0x6b: tza_imp_partial(); break;
	case 0x6c: jmp_ce_ind_partial(); break;
	case 0x6d: adc_ce_aba_partial(); break;
	case 0x6e: ror_ce_aba_partial(); break;
	case 0x6f: bbr_ce_zpb_partial(); break;
	case 0x70: bvs_ce_rel_partial(); break;
	case 0x71: adc_ce_idy_partial(); break;
	case 0x72: adc_idz_partial(); break;
	case 0x73: bvs_rw2_partial(); break;
	case 0x74: stz_ce_zpx_partial(); break;
	case 0x75: adc_ce_zpx_partial(); break;
	case 0x76: ror_ce_zpx_partial(); break;
	case 0x77: rmb_ce_bzp_partial(); break;
	case 0x78: sei_ce_imp_partial(); break;
	case 0x79: adc_ce_aby_partial(); break;
	case 0x7a: ply_ce_imp_partial(); break;
	case 0x7b: tba_imp_partial(); break;
	case 0x7c: jmp_ce_iax_partial(); break;
	case 0x7d: adc_ce_abx_partial(); break;
	case 0x7e: ror_ce_abx_partial(); break;
	case 0x7f: bbr_ce_zpb_partial(); break;
	case 0x80: bra_ce_rel_partial(); break;
	case 0x81: sta_ce_idx_partial(); break;
	case 0x82: sta_isy_partial(); break;
	case 0x83: bra_rw2_partial(); break;
	case 0x84: sty_ce_zpg_partial(); break;
	case 0x85: sta_ce_zpg_partial(); break;
	case 0x86: stx_ce_zpg_partial(); break;
	case 0x87: smb_ce_bzp_partial(); break;
	case 0x88: dey_ce_imp_partial(); break;
	case 0x89: bit_ce_imm_partial(); break;
	case 0x8a: txa_ce_imp_partial(); break;
	case 0x8b: sty_abx_partial(); break;
	case 0x8c: sty_aba_partial(); break;
	case 0x8d: sta_aba_partial(); break;
	case 0x8e: stx_aba_partial(); break;
	case 0x8f: bbs_ce_zpb_partial(); break;
	case 0x90: bcc_ce_rel_partial(); break;
	case 0x91: sta_ce_idy_partial(); break;
	case 0x92: sta_idz_partial(); break;
	case 0x93: bcc_rw2_partial(); break;
	case 0x94: sty_ce_zpx_partial(); break;
	case 0x95: sta_ce_zpx_partial(); break;
	case 0x96: stx_ce_zpy_partial(); break;
	case 0x97: smb_ce_bzp_partial(); break;
	case 0x98: tya_ce_imp_partial(); break;
	case 0x99: sta_ce_aby_partial(); break;
	case 0x9a: txs_ce_imp_partial(); break;
	case 0x9b: stx_aby_partial(); break;
	case 0x9c: stz_ce_aba_partial(); break;
	case 0x9d: sta_ce_abx_partial(); break;
	case 0x9e: stz_ce_abx_partial(); break;
	case 0x9f: bbs_ce_zpb_partial(); break;
	case 0xa0: ldy_imm_partial(); break;
	case 0xa1: lda_ce_idx_partial(); break;
	case 0xa2: ldx_imm_partial(); break;
	case 0xa3: ldz_imm_partial(); break;
	case 0xa4: ldy_ce_zpg_partial(); break;
	case 0xa5: lda_ce_zpg_partial(); break;
	case 0xa6: ldx_ce_zpg_partial(); break;
	case 0xa7: smb_ce_bzp_partial(); break;
	case 0xa8: tay_ce_imp_partial(); break;
	case 0xa9: lda_imm_partial(); break;
	case 0xaa: tax_ce_imp_partial(); break;
	case 0xab: ldz_aba_partial(); break;
	case 0xac: ldy_aba_partial(); break;
	case 0xad: lda_aba_partial(); break;
	case 0xae: ldx_aba_partial(); break;
	case 0xaf: bbs_ce_zpb_partial(); break;
	case 0xb0: bcs_ce_rel_partial(); break;
	case 0xb1: lda_ce_idy_partial(); break;
	case 0xb2: lda_idz_partial(); break;
	case 0xb3: bcs_rw2_partial(); break;
	case 0xb4: ldy_ce_zpx_partial(); break;
	case 0xb5: lda_ce_zpx_partial(); break;
	case 0xb6: ldx_ce_zpy_partial(); break;
	case 0xb7: smb_ce_bzp_partial(); break;
	case 0xb8: clv_ce_imp_partial(); break;
	case 0xb9: lda_ce_aby_partial(); break;
	case 0xba: tsx_ce_imp_partial(); break;
	case 0xbb: ldz_abx_partial(); break;
	case 0xbc: ldy_ce_abx_partial(); break;
	case 0xbd: lda_ce_abx_partial(); break;
	case 0xbe: ldx_ce_aby_partial(); break;
	case 0xbf: bbs_ce_zpb_partial(); break;
	case 0xc0: cpy_imm_partial(); break;
	case 0xc1: cmp_ce_idx_partial(); break;
	case 0xc2: cpz_imm_partial(); break;
	case 0xc3: dew_zpg_partial(); break;
	case 0xc4: cpy_ce_zpg_partial(); break;
	case 0xc5: cmp_ce_zpg_partial(); break;
	case 0xc6: dec_ce_zpg_partial(); break;
	case 0xc7: smb_ce_bzp_partial(); break;
	case 0xc8: iny_ce_imp_partial(); break;
	case 0xc9: cmp_imm_partial(); break;
	case 0xca: dex_ce_imp_partial(); break;
	case 0xcb: asw_aba_partial(); break;
	case 0xcc: cpy_aba_partial(); break;
	case 0xcd: cmp_aba_partial(); break;
	case 0xce: dec_ce_aba_partial(); break;
	case 0xcf: bbs_ce_zpb_partial(); break;
	case 0xd0: bne_ce_rel_partial(); break;
	case 0xd1: cmp_ce_idy_partial(); break;
	case 0xd2: cmp_idz_partial(); break;
	case 0xd3: bne_rw2_partial(); break;
	case 0xd4: cpz_zpg_partial(); break;
	case 0xd5: cmp_ce_zpx_partial(); break;
	case 0xd6: dec_ce_zpx_partial(); break;
	case 0xd7: smb_ce_bzp_partial(); break;
	case 0xd8: cld_ce_imp_partial(); break;
	case 0xd9: cmp_ce_aby_partial(); break;
	case 0xda: phx_ce_imp_partial(); break;
	case 0xdb: phz_imp_partial(); break;
	case 0xdc: cpz_aba_partial(); break;
	case 0xdd: cmp_ce_abx_partial(); break;
	case 0xde: dec_ce_abx_partial(); break;
	case 0xdf: bbs_ce_zpb_partial(); break;
	case 0xe0: cpx_imm_partial(); break;
	case 0xe1: sbc_ce_idx_partial(); break;
	case 0xe2: lda_isy_partial(); break;
	case 0xe3: inw_zpg_partial(); break;
	case 0xe4: cpx_ce_zpg_partial(); break;
	case 0xe5: sbc_ce_zpg_partial(); break;
	case 0xe6: inc_ce_zpg_partial(); break;
	case 0xe7: smb_ce_bzp_partial(); break;
	case 0xe8: inx_ce_imp_partial(); break;
	case 0xe9: sbc_ce_imm_partial(); break;
	case 0xea: nop_c_imp_partial(); break;
	case 0xeb: row_aba_partial(); break;
	case 0xec: cpx_aba_partial(); break;
	case 0xed: sbc_ce_aba_partial(); break;
	case 0xee: inc_ce_aba_partial(); break;
	case 0xef: bbs_ce_zpb_partial(); break;
	case 0xf0: beq_ce_rel_partial(); break;
	case 0xf1: sbc_ce_idy_partial(); break;
	case 0xf2: sbc_idz_partial(); break;
	case 0xf3: beq_rw2_partial(); break;
	case 0xf4: phw_iw2_partial(); break;
	case 0xf5: sbc_ce_zpx_partial(); break;
	case 0xf6: inc_ce_zpx_partial(); break;
	case 0xf7: smb_ce_bzp_partial(); break;
	case 0xf8: sed_ce_imp_partial(); break;
	case 0xf9: sbc_ce_aby_partial(); break;
	case 0xfa: plx_ce_imp_partial(); break;
	case 0xfb: plz_imp_partial(); break;
	case 0xfc: phw_aba_partial(); break;
	case 0xfd: sbc_ce_abx_partial(); break;
	case 0xfe: inc_ce_abx_partial(); break;
	case 0xff: bbs_ce_zpb_partial(); break;
	case STATE_RESET: reset_c_partial(); break;
	}
}

