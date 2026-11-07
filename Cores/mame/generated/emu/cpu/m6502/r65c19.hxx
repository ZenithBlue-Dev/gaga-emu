void r65c19_device::adc_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_TMP2 = read(m_TMP+m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	do_adc(m_TMP2);
	if(m_P & F_D) {
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
		set_nz(m_A);
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

void r65c19_device::adc_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_TMP2 = read(m_TMP+m_X);
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
	do_adc(m_TMP2);
	if(m_P & F_D) {
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
		set_nz(m_A);
	}
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

void r65c19_device::add_imm_full()
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
	do_add(m_TMP);
	if(m_P & F_D) {
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
		set_nz(m_A);
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

void r65c19_device::add_imm_partial()
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
	do_add(m_TMP);
	if(m_P & F_D) {
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
		set_nz(m_A);
	}
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

void r65c19_device::add_zpg_full()
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
	do_add(m_TMP2);
	if(m_P & F_D) {
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
		set_nz(m_A);
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

void r65c19_device::add_zpg_partial()
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
	do_add(m_TMP2);
	if(m_P & F_D) {
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
		set_nz(m_A);
	}
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

void r65c19_device::add_zpx_full()
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
	m_TMP2 = read(uint8_t(m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	do_add(m_TMP2);
	if(m_P & F_D) {
		read_pc();
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

void r65c19_device::add_zpx_partial()
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
	m_TMP2 = read(uint8_t(m_TMP+m_X));
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
	do_add(m_TMP2);
	if(m_P & F_D) {
	[[fallthrough]];
case 7:
		read_pc();
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
	}
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

void r65c19_device::and_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_TMP2 = read(m_TMP+m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
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
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void r65c19_device::and_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_TMP2 = read(m_TMP+m_X);
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
	m_A &= m_TMP2;
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

void r65c19_device::asr_acc_full()
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
	m_A = do_asr(m_A);
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

void r65c19_device::asr_acc_partial()
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
	m_A = do_asr(m_A);
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

void r65c19_device::bar_amr_full()
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
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_PC++;
	m_TMP2 = ~m_TMP2 & m_TMP;
	m_TMP = read_pc();
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
	if(m_TMP2 != 0) {
		read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
		if(page_changing(m_PC, int8_t(m_TMP))) {
			read_arg(set_l(m_PC, m_PC+int8_t(m_TMP)));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 15;
		} else
			m_inst_substate = 16;
		return;
	}
		}
		m_PC += int8_t(m_TMP);
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 17;
		} else
			m_inst_substate = 18;
		return;
	}
	prefetch_end();
}

void r65c19_device::bar_amr_partial()
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
	[[fallthrough]];
case 7:
	m_TMP = read_pc();
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
	read_pc();
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
	m_PC++;
	m_TMP2 = ~m_TMP2 & m_TMP;
	[[fallthrough]];
case 11:
	m_TMP = read_pc();
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
	if(m_TMP2 != 0) {
	[[fallthrough]];
case 13:
		read_pc();
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
		if(page_changing(m_PC, int8_t(m_TMP))) {
	[[fallthrough]];
case 15:
			read_arg(set_l(m_PC, m_PC+int8_t(m_TMP)));
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
		}
		m_PC += int8_t(m_TMP);
	}
	prefetch_start();
	[[fallthrough]];
case 17:
	m_IR = read_sync(m_PC);
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
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void r65c19_device::bas_amr_full()
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
	m_TMP = read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_PC++;
	m_TMP2 &= m_TMP;
	m_TMP = read_pc();
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
	if(m_TMP2 != 0) {
		read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
		if(page_changing(m_PC, int8_t(m_TMP))) {
			read_arg(set_l(m_PC, m_PC+int8_t(m_TMP)));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 15;
		} else
			m_inst_substate = 16;
		return;
	}
		}
		m_PC += int8_t(m_TMP);
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 17;
		} else
			m_inst_substate = 18;
		return;
	}
	prefetch_end();
}

void r65c19_device::bas_amr_partial()
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
	[[fallthrough]];
case 7:
	m_TMP = read_pc();
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
	read_pc();
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
	m_PC++;
	m_TMP2 &= m_TMP;
	[[fallthrough]];
case 11:
	m_TMP = read_pc();
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
	if(m_TMP2 != 0) {
	[[fallthrough]];
case 13:
		read_pc();
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
		if(page_changing(m_PC, int8_t(m_TMP))) {
	[[fallthrough]];
case 15:
			read_arg(set_l(m_PC, m_PC+int8_t(m_TMP)));
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
		}
		m_PC += int8_t(m_TMP);
	}
	prefetch_start();
	[[fallthrough]];
case 17:
	m_IR = read_sync(m_PC);
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
	prefetch_end();
	break;
}
	m_inst_substate = 0;
}

void r65c19_device::brk_r_imp_full()
{
	if(m_irq_taken || m_nmi_pending) {
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
	dec_SP();
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
	dec_SP();
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
	dec_SP();
	if(m_irq_taken && m_nmi_pending) {
		standard_irq_callback(NMI_LINE, m_PC);
		m_PC = read_arg(0xfffc);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
		m_PC = set_h(m_PC, read_arg(0xfffd));
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
		if(m_irq_taken)
			standard_irq_callback(((~m_TMP & 0x000e) >> 1) - 1, m_PC);
		m_TMP = get_irq_vector();
		m_PC = read_arg(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 15;
		} else
			m_inst_substate = 16;
		return;
	}
		m_PC = set_h(m_PC, read_arg(m_TMP+1));
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

void r65c19_device::brk_r_imp_partial()
{
	switch(m_inst_substate) {
case 0:
	if(m_irq_taken || m_nmi_pending) {
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
	dec_SP();
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
	dec_SP();
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
	dec_SP();
	if(m_irq_taken && m_nmi_pending) {
		standard_irq_callback(NMI_LINE, m_PC);
	[[fallthrough]];
case 11:
		m_PC = read_arg(0xfffc);
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
		m_PC = set_h(m_PC, read_arg(0xfffd));
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
		if(m_irq_taken)
			standard_irq_callback(((~m_TMP & 0x000e) >> 1) - 1, m_PC);
		m_TMP = get_irq_vector();
	[[fallthrough]];
case 15:
		m_PC = read_arg(m_TMP);
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
		m_PC = set_h(m_PC, read_arg(m_TMP+1));
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

void r65c19_device::clw_imp_full()
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
	m_P &= ~F_V;
	m_w = 0;
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

void r65c19_device::clw_imp_partial()
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
	m_P &= ~F_V;
	m_w = 0;
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

void r65c19_device::cmp_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_TMP2 = read(m_TMP+m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	do_cmp(m_A, m_TMP2);
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

void r65c19_device::cmp_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_TMP2 = read(m_TMP+m_X);
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
	do_cmp(m_A, m_TMP2);
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

void r65c19_device::eor_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_TMP2 = read(m_TMP+m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
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
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void r65c19_device::eor_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_TMP2 = read(m_TMP+m_X);
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
	m_A ^= m_TMP2;
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

void r65c19_device::exc_zpx_full()
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
	m_TMP = uint8_t(m_TMP+m_X);
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
	m_A = m_TMP2;
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

void r65c19_device::exc_zpx_partial()
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
	m_TMP = uint8_t(m_TMP+m_X);
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
	m_A = m_TMP2;
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

void r65c19_device::ini_imp_full()
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
	read(m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_i++;
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

void r65c19_device::ini_imp_partial()
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
	read(m_i);
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
	m_i++;
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

void r65c19_device::jpi_ind_full()
{
	m_i = m_PC;
	m_TMP = read_arg(m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 1;
		} else
			m_inst_substate = 2;
		return;
	}
	m_TMP = set_h(m_TMP, read_arg(m_i+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_i += 2;
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

void r65c19_device::jpi_ind_partial()
{
	switch(m_inst_substate) {
case 0:
	m_i = m_PC;
	[[fallthrough]];
case 1:
	m_TMP = read_arg(m_i);
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
	m_TMP = set_h(m_TMP, read_arg(m_i+1));
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
	m_i += 2;
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

void r65c19_device::jsb_vec_full()
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
	dec_SP();
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
	dec_SP();
	m_TMP = 0xffe0 | ((m_inst_state >> 3) & 0x0e);
	m_PC = read_arg(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_PC = set_h(m_PC, read_arg(m_TMP+1));
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

void r65c19_device::jsb_vec_partial()
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
	dec_SP();
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
	dec_SP();
	m_TMP = 0xffe0 | ((m_inst_state >> 3) & 0x0e);
	[[fallthrough]];
case 7:
	m_PC = read_arg(m_TMP);
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
	m_PC = set_h(m_PC, read_arg(m_TMP+1));
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

void r65c19_device::jmp_r_ind_full()
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

void r65c19_device::jmp_r_ind_partial()
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

void r65c19_device::jsr_r_adr_full()
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
	write(m_SP, m_PC>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP();
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
	dec_SP();
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

void r65c19_device::jsr_r_adr_partial()
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
	write(m_SP, m_PC>>8);
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
	dec_SP();
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
	dec_SP();
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

void r65c19_device::lab_acc_full()
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
	if(int8_t(m_A) < 0)
		m_A = -m_A;
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

void r65c19_device::lab_acc_partial()
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
	if(int8_t(m_A) < 0)
		m_A = -m_A;
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

void r65c19_device::lai_imp_full()
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
	m_A = read(m_i);
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

void r65c19_device::lai_imp_partial()
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
	m_A = read(m_i);
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

void r65c19_device::lan_imp_full()
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
	m_A = read(m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_i++;
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

void r65c19_device::lan_imp_partial()
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
	m_A = read(m_i);
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
	m_i++;
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

void r65c19_device::lda_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_A = read(m_TMP+m_X);
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

void r65c19_device::lda_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_A = read(m_TMP+m_X);
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

void r65c19_device::lii_imp_full()
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
	m_TMP = read(m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read(m_i+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_i = m_TMP;
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

void r65c19_device::lii_imp_partial()
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
	m_TMP = read(m_i);
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
	m_TMP = set_h(m_TMP, read(m_i+1));
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
	read(m_TMP);
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
	m_i = m_TMP;
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

void r65c19_device::mpa_imp_full()
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
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_TMP = int8_t(m_A) * int8_t(m_Y);
	m_w = do_accumulate(m_TMP, m_w);
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

void r65c19_device::mpa_imp_partial()
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
	[[fallthrough]];
case 7:
	read_pc();
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
	read_pc();
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
	m_TMP = int8_t(m_A) * int8_t(m_Y);
	m_w = do_accumulate(m_TMP, m_w);
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

void r65c19_device::mpy_imp_full()
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
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	read_pc();
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_TMP = int8_t(m_A) * int8_t(m_Y);
	m_A = do_accumulate(m_TMP, 0)>>8;
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

void r65c19_device::mpy_imp_partial()
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
	[[fallthrough]];
case 7:
	read_pc();
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
	read_pc();
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
	m_TMP = int8_t(m_A) * int8_t(m_Y);
	m_A = do_accumulate(m_TMP, 0)>>8;
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

void r65c19_device::neg_acc_full()
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

void r65c19_device::neg_acc_partial()
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

void r65c19_device::nxt_imp_full()
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
	m_PC = read(m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_PC = set_h(m_PC, read(m_i+1));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	m_i += 2;
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

void r65c19_device::nxt_imp_partial()
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
	m_PC = read(m_i);
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
	m_PC = set_h(m_PC, read(m_i+1));
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
	m_i += 2;
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

void r65c19_device::ora_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_TMP2 = read(m_TMP+m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
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
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	prefetch_end();
}

void r65c19_device::ora_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_TMP2 = read(m_TMP+m_X);
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
	m_A |= m_TMP2;
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

void r65c19_device::phi_imp_full()
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
	write(m_SP, m_i>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP();
	write(m_SP, m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP();
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

void r65c19_device::phi_imp_partial()
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
	write(m_SP, m_i>>8);
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
	dec_SP();
	[[fallthrough]];
case 5:
	write(m_SP, m_i);
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
	dec_SP();
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

void r65c19_device::phw_imp_full()
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
	write(m_SP, m_w>>8);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	dec_SP();
	write(m_SP, m_w);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP();
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

void r65c19_device::phw_imp_partial()
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
	write(m_SP, m_w>>8);
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
	dec_SP();
	[[fallthrough]];
case 5:
	write(m_SP, m_w);
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
	dec_SP();
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

void r65c19_device::pia_imp_full()
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
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	inc_SP();
	m_i = read(m_SP);
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
	m_i = set_h(m_i, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	m_A = read(m_i);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_i++;
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

void r65c19_device::pia_imp_partial()
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
	read(m_SP);
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
	inc_SP();
	[[fallthrough]];
case 5:
	m_i = read(m_SP);
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
	m_i = set_h(m_i, read(m_SP));
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
	m_A = read(m_i);
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
	m_i++;
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

void r65c19_device::pli_imp_full()
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
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	inc_SP();
	m_i = read(m_SP);
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
	m_i = set_h(m_i, read(m_SP));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	read(m_i);
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

void r65c19_device::pli_imp_partial()
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
	read(m_SP);
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
	inc_SP();
	[[fallthrough]];
case 5:
	m_i = read(m_SP);
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
	m_i = set_h(m_i, read(m_SP));
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
	read(m_i);
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

void r65c19_device::plw_imp_full()
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
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	inc_SP();
	m_w = read(m_SP);
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
	m_w = set_h(m_w, read(m_SP));
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

void r65c19_device::plw_imp_partial()
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
	read(m_SP);
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
	inc_SP();
	[[fallthrough]];
case 5:
	m_w = read(m_SP);
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
	m_w = set_h(m_w, read(m_SP));
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

void r65c19_device::psh_imp_full()
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
	dec_SP();
	write(m_SP, m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	dec_SP();
	write(m_SP, m_Y);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	dec_SP();
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

void r65c19_device::psh_imp_partial()
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
	dec_SP();
	[[fallthrough]];
case 5:
	write(m_SP, m_X);
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
	dec_SP();
	[[fallthrough]];
case 7:
	write(m_SP, m_Y);
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
	dec_SP();
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

void r65c19_device::pul_imp_full()
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
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	inc_SP();
	m_Y = read(m_SP);
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
	m_X = read(m_SP);
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
	m_A = read(m_SP);
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

void r65c19_device::pul_imp_partial()
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
	read(m_SP);
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
	inc_SP();
	[[fallthrough]];
case 5:
	m_Y = read(m_SP);
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
	m_X = read(m_SP);
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
	m_A = read(m_SP);
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

void r65c19_device::rba_ima_full()
{
	m_A = read_pc(); // "Note that Accumulator contents are altered by RBA and SBA" (C29/C39 Technical Reference Manual, p. C-29)
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
	m_TMP = set_h(m_TMP, read_pc());
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
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_TMP2 &= ~m_A;
	write(m_TMP, m_TMP2);
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

void r65c19_device::rba_ima_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_A = read_pc(); // "Note that Accumulator contents are altered by RBA and SBA" (C29/C39 Technical Reference Manual, p. C-29)
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
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read_pc());
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
	[[fallthrough]];
case 9:
	read(m_TMP);
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
	m_TMP2 &= ~m_A;
	[[fallthrough]];
case 11:
	write(m_TMP, m_TMP2);
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

void r65c19_device::rnd_imp_full()
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
	m_TMP = set_l(m_w, m_Y);
	m_A = do_accumulate(m_TMP, (m_w<<1) & 0x100)>>8;
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

void r65c19_device::rnd_imp_partial()
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
	m_TMP = set_l(m_w, m_Y);
	m_A = do_accumulate(m_TMP, (m_w<<1) & 0x100)>>8;
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

void r65c19_device::rts_r_imp_full()
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
	inc_SP();
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
	inc_SP();
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

void r65c19_device::rts_r_imp_partial()
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
	inc_SP();
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
	inc_SP();
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

void r65c19_device::sba_ima_full()
{
	m_A = read_pc();
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
	m_TMP = set_h(m_TMP, read_pc());
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
	read(m_TMP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	m_TMP2 |= m_A;
	write(m_TMP, m_TMP2);
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

void r65c19_device::sba_ima_partial()
{
	switch(m_inst_substate) {
case 0:
	[[fallthrough]];
case 1:
	m_A = read_pc();
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
	[[fallthrough]];
case 5:
	m_TMP = set_h(m_TMP, read_pc());
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
	[[fallthrough]];
case 9:
	read(m_TMP);
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
	m_TMP2 |= m_A;
	[[fallthrough]];
case 11:
	write(m_TMP, m_TMP2);
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

void r65c19_device::sbc_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	if(page_changing(m_TMP, m_X)) {
		read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	}
	m_TMP2 = read(m_TMP+m_X);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	do_sbc_c(m_TMP2);
	if(m_P & F_D) {
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
		set_nz(m_A);
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

void r65c19_device::sbc_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	if(page_changing(m_TMP, m_X)) {
	[[fallthrough]];
case 7:
		read(set_l(m_TMP, m_TMP+m_X));
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
	}
	[[fallthrough]];
case 9:
	m_TMP2 = read(m_TMP+m_X);
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
	do_sbc_c(m_TMP2);
	if(m_P & F_D) {
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
		set_nz(m_A);
	}
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

void r65c19_device::sta_ipx_full()
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
	m_TMP = read(m_TMP2);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 3;
		} else
			m_inst_substate = 4;
		return;
	}
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 5;
		} else
			m_inst_substate = 6;
		return;
	}
	read(set_l(m_TMP, m_TMP+m_X));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	write(m_TMP+m_X, m_A);
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

void r65c19_device::sta_ipx_partial()
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
	m_TMP = read(m_TMP2);
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
	m_TMP = set_h(m_TMP, read((m_TMP2+1) & 0xff));
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
	read(set_l(m_TMP, m_TMP+m_X));
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
	write(m_TMP+m_X, m_A);
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

void r65c19_device::sti_imz_full()
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
	m_TMP2 = read_pc();
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
	write(m_TMP2, m_TMP);
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

void r65c19_device::sti_imz_partial()
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
	m_TMP2 = read_pc();
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
	write(m_TMP2, m_TMP);
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

void r65c19_device::taw_imp_full()
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
	m_w = m_A<<8;
	set_nz(m_w>>8);
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

void r65c19_device::taw_imp_partial()
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
	m_w = m_A<<8;
	set_nz(m_w>>8);
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

void r65c19_device::tip_imp_full()
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
	m_PC = m_i;
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

void r65c19_device::tip_imp_partial()
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
	m_PC = m_i;
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

void r65c19_device::twa_imp_full()
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
	m_A = m_w>>8;
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

void r65c19_device::twa_imp_partial()
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
	m_A = m_w>>8;
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

void r65c19_device::reset_r_full()
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
	dec_SP();
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 7;
		} else
			m_inst_substate = 8;
		return;
	}
	dec_SP();
	read(m_SP);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 9;
		} else
			m_inst_substate = 10;
		return;
	}
	dec_SP();
	m_P = (m_P | F_I) & ~F_D;
	m_PC = read_arg(0xfffe);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 11;
		} else
			m_inst_substate = 12;
		return;
	}
	m_PC = set_h(m_PC, read_arg(0xffff));
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 13;
		} else
			m_inst_substate = 14;
		return;
	}
	prefetch_start();
	m_IR = read_sync(m_PC);
	m_icount--;
	if(m_icount <= 0) {
		if(access_to_be_redone()) {
			m_icount++;
			m_inst_substate = 15;
		} else
			m_inst_substate = 16;
		return;
	}
	prefetch_end();
	m_inst_state = -1;
}

void r65c19_device::reset_r_partial()
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
	dec_SP();
	[[fallthrough]];
case 7:
	read(m_SP);
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
	dec_SP();
	[[fallthrough]];
case 9:
	read(m_SP);
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
	dec_SP();
	m_P = (m_P | F_I) & ~F_D;
	[[fallthrough]];
case 11:
	m_PC = read_arg(0xfffe);
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
	m_PC = set_h(m_PC, read_arg(0xffff));
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
	prefetch_start();
	[[fallthrough]];
case 15:
	m_IR = read_sync(m_PC);
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
	prefetch_end();
	m_inst_state = -1;
	break;
}
	m_inst_substate = 0;
}



void r65c19_device::do_exec_full()
{
	switch(m_inst_state) {

	case 0x00: brk_r_imp_full(); break;
	case 0x01: ora_zpi_full(); break;
	case 0x02: mpy_imp_full(); break;
	case 0x03: tip_imp_full(); break;
	case 0x04: nop_zpg_full(); break;
	case 0x05: ora_zpg_full(); break;
	case 0x06: asl_c_zpg_full(); break;
	case 0x07: rmb_bzp_full(); break;
	case 0x08: php_imp_full(); break;
	case 0x09: ora_imm_full(); break;
	case 0x0a: asl_acc_full(); break;
	case 0x0b: jsb_vec_full(); break;
	case 0x0c: jpi_ind_full(); break;
	case 0x0d: ora_aba_full(); break;
	case 0x0e: asl_c_aba_full(); break;
	case 0x0f: bbr_zpb_full(); break;
	case 0x10: bpl_rel_full(); break;
	case 0x11: ora_ipx_full(); break;
	case 0x12: mpa_imp_full(); break;
	case 0x13: lab_acc_full(); break;
	case 0x14: nop_zpx_full(); break;
	case 0x15: ora_zpx_full(); break;
	case 0x16: asl_c_zpx_full(); break;
	case 0x17: rmb_bzp_full(); break;
	case 0x18: clc_imp_full(); break;
	case 0x19: ora_aby_full(); break;
	case 0x1a: neg_acc_full(); break;
	case 0x1b: jsb_vec_full(); break;
	case 0x1c: nop_c_abx_full(); break;
	case 0x1d: ora_abx_full(); break;
	case 0x1e: asl_c_abx_full(); break;
	case 0x1f: bbr_zpb_full(); break;
	case 0x20: jsr_r_adr_full(); break;
	case 0x21: and_zpi_full(); break;
	case 0x22: psh_imp_full(); break;
	case 0x23: phw_imp_full(); break;
	case 0x24: bit_zpg_full(); break;
	case 0x25: and_zpg_full(); break;
	case 0x26: rol_c_zpg_full(); break;
	case 0x27: rmb_bzp_full(); break;
	case 0x28: plp_imp_full(); break;
	case 0x29: and_imm_full(); break;
	case 0x2a: rol_acc_full(); break;
	case 0x2b: jsb_vec_full(); break;
	case 0x2c: bit_aba_full(); break;
	case 0x2d: and_aba_full(); break;
	case 0x2e: rol_c_aba_full(); break;
	case 0x2f: bbr_zpb_full(); break;
	case 0x30: bmi_rel_full(); break;
	case 0x31: and_ipx_full(); break;
	case 0x32: pul_imp_full(); break;
	case 0x33: plw_imp_full(); break;
	case 0x34: nop_zpx_full(); break;
	case 0x35: and_zpx_full(); break;
	case 0x36: rol_c_zpx_full(); break;
	case 0x37: rmb_bzp_full(); break;
	case 0x38: sec_imp_full(); break;
	case 0x39: and_aby_full(); break;
	case 0x3a: asr_acc_full(); break;
	case 0x3b: jsb_vec_full(); break;
	case 0x3c: nop_c_abx_full(); break;
	case 0x3d: and_abx_full(); break;
	case 0x3e: rol_c_abx_full(); break;
	case 0x3f: bbr_zpb_full(); break;
	case 0x40: rti_imp_full(); break;
	case 0x41: eor_zpi_full(); break;
	case 0x42: rnd_imp_full(); break;
	case 0x43: nop_c_imp_full(); break;
	case 0x44: nop_zpg_full(); break;
	case 0x45: eor_zpg_full(); break;
	case 0x46: lsr_c_zpg_full(); break;
	case 0x47: rmb_bzp_full(); break;
	case 0x48: pha_imp_full(); break;
	case 0x49: eor_imm_full(); break;
	case 0x4a: lsr_acc_full(); break;
	case 0x4b: jsb_vec_full(); break;
	case 0x4c: jmp_adr_full(); break;
	case 0x4d: eor_aba_full(); break;
	case 0x4e: lsr_c_aba_full(); break;
	case 0x4f: bbr_zpb_full(); break;
	case 0x50: bvc_rel_full(); break;
	case 0x51: eor_ipx_full(); break;
	case 0x52: clw_imp_full(); break;
	case 0x53: nop_c_imp_full(); break;
	case 0x54: nop_zpx_full(); break;
	case 0x55: eor_zpx_full(); break;
	case 0x56: lsr_c_zpx_full(); break;
	case 0x57: rmb_bzp_full(); break;
	case 0x58: cli_imp_full(); break;
	case 0x59: eor_aby_full(); break;
	case 0x5a: phy_imp_full(); break;
	case 0x5b: jsb_vec_full(); break;
	case 0x5c: nop_c_abx_full(); break;
	case 0x5d: eor_abx_full(); break;
	case 0x5e: lsr_c_abx_full(); break;
	case 0x5f: bbr_zpb_full(); break;
	case 0x60: rts_r_imp_full(); break;
	case 0x61: adc_c_zpi_full(); break;
	case 0x62: taw_imp_full(); break;
	case 0x63: nop_c_imp_full(); break;
	case 0x64: add_zpg_full(); break;
	case 0x65: adc_c_zpg_full(); break;
	case 0x66: ror_c_zpg_full(); break;
	case 0x67: rmb_bzp_full(); break;
	case 0x68: pla_imp_full(); break;
	case 0x69: adc_c_imm_full(); break;
	case 0x6a: ror_acc_full(); break;
	case 0x6b: jsb_vec_full(); break;
	case 0x6c: jmp_r_ind_full(); break;
	case 0x6d: adc_c_aba_full(); break;
	case 0x6e: ror_c_aba_full(); break;
	case 0x6f: bbr_zpb_full(); break;
	case 0x70: bvs_rel_full(); break;
	case 0x71: adc_ipx_full(); break;
	case 0x72: twa_imp_full(); break;
	case 0x73: nop_c_imp_full(); break;
	case 0x74: add_zpx_full(); break;
	case 0x75: adc_c_zpx_full(); break;
	case 0x76: ror_c_zpx_full(); break;
	case 0x77: rmb_bzp_full(); break;
	case 0x78: sei_imp_full(); break;
	case 0x79: adc_c_aby_full(); break;
	case 0x7a: ply_imp_full(); break;
	case 0x7b: jsb_vec_full(); break;
	case 0x7c: jmp_iax_full(); break;
	case 0x7d: adc_c_abx_full(); break;
	case 0x7e: ror_c_abx_full(); break;
	case 0x7f: bbr_zpb_full(); break;
	case 0x80: bra_rel_full(); break;
	case 0x81: sta_zpi_full(); break;
	case 0x82: nop_imm_full(); break;
	case 0x83: nop_c_imp_full(); break;
	case 0x84: sty_zpg_full(); break;
	case 0x85: sta_zpg_full(); break;
	case 0x86: stx_zpg_full(); break;
	case 0x87: smb_bzp_full(); break;
	case 0x88: dey_imp_full(); break;
	case 0x89: add_imm_full(); break;
	case 0x8a: txa_imp_full(); break;
	case 0x8b: nxt_imp_full(); break;
	case 0x8c: sty_aba_full(); break;
	case 0x8d: sta_aba_full(); break;
	case 0x8e: stx_aba_full(); break;
	case 0x8f: bbs_zpb_full(); break;
	case 0x90: bcc_rel_full(); break;
	case 0x91: sta_ipx_full(); break;
	case 0x92: nop_imm_full(); break;
	case 0x93: nop_c_imp_full(); break;
	case 0x94: sty_zpx_full(); break;
	case 0x95: sta_zpx_full(); break;
	case 0x96: stx_zpy_full(); break;
	case 0x97: smb_bzp_full(); break;
	case 0x98: tya_imp_full(); break;
	case 0x99: sta_aby_full(); break;
	case 0x9a: txs_imp_full(); break;
	case 0x9b: lii_imp_full(); break;
	case 0x9c: nop_c_abx_full(); break;
	case 0x9d: sta_abx_full(); break;
	case 0x9e: nop_c_abx_full(); break;
	case 0x9f: bbs_zpb_full(); break;
	case 0xa0: ldy_imm_full(); break;
	case 0xa1: lda_zpi_full(); break;
	case 0xa2: ldx_imm_full(); break;
	case 0xa3: nop_c_imp_full(); break;
	case 0xa4: ldy_zpg_full(); break;
	case 0xa5: lda_zpg_full(); break;
	case 0xa6: ldx_zpg_full(); break;
	case 0xa7: smb_bzp_full(); break;
	case 0xa8: tay_imp_full(); break;
	case 0xa9: lda_imm_full(); break;
	case 0xaa: tax_imp_full(); break;
	case 0xab: lan_imp_full(); break;
	case 0xac: ldy_aba_full(); break;
	case 0xad: lda_aba_full(); break;
	case 0xae: ldx_aba_full(); break;
	case 0xaf: bbs_zpb_full(); break;
	case 0xb0: bcs_rel_full(); break;
	case 0xb1: lda_ipx_full(); break;
	case 0xb2: sti_imz_full(); break;
	case 0xb3: nop_c_imp_full(); break;
	case 0xb4: ldy_zpx_full(); break;
	case 0xb5: lda_zpx_full(); break;
	case 0xb6: ldx_zpy_full(); break;
	case 0xb7: smb_bzp_full(); break;
	case 0xb8: clv_imp_full(); break;
	case 0xb9: lda_aby_full(); break;
	case 0xba: tsx_imp_full(); break;
	case 0xbb: ini_imp_full(); break;
	case 0xbc: ldy_abx_full(); break;
	case 0xbd: lda_abx_full(); break;
	case 0xbe: ldx_aby_full(); break;
	case 0xbf: bbs_zpb_full(); break;
	case 0xc0: cpy_imm_full(); break;
	case 0xc1: cmp_zpi_full(); break;
	case 0xc2: rba_ima_full(); break;
	case 0xc3: nop_c_imp_full(); break;
	case 0xc4: cpy_zpg_full(); break;
	case 0xc5: cmp_zpg_full(); break;
	case 0xc6: dec_c_zpg_full(); break;
	case 0xc7: smb_bzp_full(); break;
	case 0xc8: iny_imp_full(); break;
	case 0xc9: cmp_imm_full(); break;
	case 0xca: dex_imp_full(); break;
	case 0xcb: phi_imp_full(); break;
	case 0xcc: cpy_aba_full(); break;
	case 0xcd: cmp_aba_full(); break;
	case 0xce: dec_c_aba_full(); break;
	case 0xcf: bbs_zpb_full(); break;
	case 0xd0: bne_rel_full(); break;
	case 0xd1: cmp_ipx_full(); break;
	case 0xd2: sba_ima_full(); break;
	case 0xd3: nop_c_imp_full(); break;
	case 0xd4: exc_zpx_full(); break;
	case 0xd5: cmp_zpx_full(); break;
	case 0xd6: dec_c_zpx_full(); break;
	case 0xd7: smb_bzp_full(); break;
	case 0xd8: cld_imp_full(); break;
	case 0xd9: cmp_aby_full(); break;
	case 0xda: phx_imp_full(); break;
	case 0xdb: pli_imp_full(); break;
	case 0xdc: nop_c_abx_full(); break;
	case 0xdd: cmp_abx_full(); break;
	case 0xde: dec_c_abx_full(); break;
	case 0xdf: bbs_zpb_full(); break;
	case 0xe0: cpx_imm_full(); break;
	case 0xe1: sbc_c_zpi_full(); break;
	case 0xe2: bar_amr_full(); break;
	case 0xe3: nop_c_imp_full(); break;
	case 0xe4: cpx_zpg_full(); break;
	case 0xe5: sbc_c_zpg_full(); break;
	case 0xe6: inc_c_zpg_full(); break;
	case 0xe7: smb_bzp_full(); break;
	case 0xe8: inx_imp_full(); break;
	case 0xe9: sbc_c_imm_full(); break;
	case 0xea: nop_imp_full(); break;
	case 0xeb: lai_imp_full(); break;
	case 0xec: cpx_aba_full(); break;
	case 0xed: sbc_c_aba_full(); break;
	case 0xee: inc_c_aba_full(); break;
	case 0xef: bbs_zpb_full(); break;
	case 0xf0: beq_rel_full(); break;
	case 0xf1: sbc_ipx_full(); break;
	case 0xf2: bas_amr_full(); break;
	case 0xf3: nop_c_imp_full(); break;
	case 0xf4: nop_zpx_full(); break;
	case 0xf5: sbc_c_zpx_full(); break;
	case 0xf6: inc_c_zpx_full(); break;
	case 0xf7: smb_bzp_full(); break;
	case 0xf8: sed_imp_full(); break;
	case 0xf9: sbc_c_aby_full(); break;
	case 0xfa: plx_imp_full(); break;
	case 0xfb: pia_imp_full(); break;
	case 0xfc: nop_c_abx_full(); break;
	case 0xfd: sbc_c_abx_full(); break;
	case 0xfe: inc_c_abx_full(); break;
	case 0xff: bbs_zpb_full(); break;
	case STATE_RESET: reset_r_full(); break;
	}
}

void r65c19_device::do_exec_partial()
{
	switch(m_inst_state) {

	case 0x00: brk_r_imp_partial(); break;
	case 0x01: ora_zpi_partial(); break;
	case 0x02: mpy_imp_partial(); break;
	case 0x03: tip_imp_partial(); break;
	case 0x04: nop_zpg_partial(); break;
	case 0x05: ora_zpg_partial(); break;
	case 0x06: asl_c_zpg_partial(); break;
	case 0x07: rmb_bzp_partial(); break;
	case 0x08: php_imp_partial(); break;
	case 0x09: ora_imm_partial(); break;
	case 0x0a: asl_acc_partial(); break;
	case 0x0b: jsb_vec_partial(); break;
	case 0x0c: jpi_ind_partial(); break;
	case 0x0d: ora_aba_partial(); break;
	case 0x0e: asl_c_aba_partial(); break;
	case 0x0f: bbr_zpb_partial(); break;
	case 0x10: bpl_rel_partial(); break;
	case 0x11: ora_ipx_partial(); break;
	case 0x12: mpa_imp_partial(); break;
	case 0x13: lab_acc_partial(); break;
	case 0x14: nop_zpx_partial(); break;
	case 0x15: ora_zpx_partial(); break;
	case 0x16: asl_c_zpx_partial(); break;
	case 0x17: rmb_bzp_partial(); break;
	case 0x18: clc_imp_partial(); break;
	case 0x19: ora_aby_partial(); break;
	case 0x1a: neg_acc_partial(); break;
	case 0x1b: jsb_vec_partial(); break;
	case 0x1c: nop_c_abx_partial(); break;
	case 0x1d: ora_abx_partial(); break;
	case 0x1e: asl_c_abx_partial(); break;
	case 0x1f: bbr_zpb_partial(); break;
	case 0x20: jsr_r_adr_partial(); break;
	case 0x21: and_zpi_partial(); break;
	case 0x22: psh_imp_partial(); break;
	case 0x23: phw_imp_partial(); break;
	case 0x24: bit_zpg_partial(); break;
	case 0x25: and_zpg_partial(); break;
	case 0x26: rol_c_zpg_partial(); break;
	case 0x27: rmb_bzp_partial(); break;
	case 0x28: plp_imp_partial(); break;
	case 0x29: and_imm_partial(); break;
	case 0x2a: rol_acc_partial(); break;
	case 0x2b: jsb_vec_partial(); break;
	case 0x2c: bit_aba_partial(); break;
	case 0x2d: and_aba_partial(); break;
	case 0x2e: rol_c_aba_partial(); break;
	case 0x2f: bbr_zpb_partial(); break;
	case 0x30: bmi_rel_partial(); break;
	case 0x31: and_ipx_partial(); break;
	case 0x32: pul_imp_partial(); break;
	case 0x33: plw_imp_partial(); break;
	case 0x34: nop_zpx_partial(); break;
	case 0x35: and_zpx_partial(); break;
	case 0x36: rol_c_zpx_partial(); break;
	case 0x37: rmb_bzp_partial(); break;
	case 0x38: sec_imp_partial(); break;
	case 0x39: and_aby_partial(); break;
	case 0x3a: asr_acc_partial(); break;
	case 0x3b: jsb_vec_partial(); break;
	case 0x3c: nop_c_abx_partial(); break;
	case 0x3d: and_abx_partial(); break;
	case 0x3e: rol_c_abx_partial(); break;
	case 0x3f: bbr_zpb_partial(); break;
	case 0x40: rti_imp_partial(); break;
	case 0x41: eor_zpi_partial(); break;
	case 0x42: rnd_imp_partial(); break;
	case 0x43: nop_c_imp_partial(); break;
	case 0x44: nop_zpg_partial(); break;
	case 0x45: eor_zpg_partial(); break;
	case 0x46: lsr_c_zpg_partial(); break;
	case 0x47: rmb_bzp_partial(); break;
	case 0x48: pha_imp_partial(); break;
	case 0x49: eor_imm_partial(); break;
	case 0x4a: lsr_acc_partial(); break;
	case 0x4b: jsb_vec_partial(); break;
	case 0x4c: jmp_adr_partial(); break;
	case 0x4d: eor_aba_partial(); break;
	case 0x4e: lsr_c_aba_partial(); break;
	case 0x4f: bbr_zpb_partial(); break;
	case 0x50: bvc_rel_partial(); break;
	case 0x51: eor_ipx_partial(); break;
	case 0x52: clw_imp_partial(); break;
	case 0x53: nop_c_imp_partial(); break;
	case 0x54: nop_zpx_partial(); break;
	case 0x55: eor_zpx_partial(); break;
	case 0x56: lsr_c_zpx_partial(); break;
	case 0x57: rmb_bzp_partial(); break;
	case 0x58: cli_imp_partial(); break;
	case 0x59: eor_aby_partial(); break;
	case 0x5a: phy_imp_partial(); break;
	case 0x5b: jsb_vec_partial(); break;
	case 0x5c: nop_c_abx_partial(); break;
	case 0x5d: eor_abx_partial(); break;
	case 0x5e: lsr_c_abx_partial(); break;
	case 0x5f: bbr_zpb_partial(); break;
	case 0x60: rts_r_imp_partial(); break;
	case 0x61: adc_c_zpi_partial(); break;
	case 0x62: taw_imp_partial(); break;
	case 0x63: nop_c_imp_partial(); break;
	case 0x64: add_zpg_partial(); break;
	case 0x65: adc_c_zpg_partial(); break;
	case 0x66: ror_c_zpg_partial(); break;
	case 0x67: rmb_bzp_partial(); break;
	case 0x68: pla_imp_partial(); break;
	case 0x69: adc_c_imm_partial(); break;
	case 0x6a: ror_acc_partial(); break;
	case 0x6b: jsb_vec_partial(); break;
	case 0x6c: jmp_r_ind_partial(); break;
	case 0x6d: adc_c_aba_partial(); break;
	case 0x6e: ror_c_aba_partial(); break;
	case 0x6f: bbr_zpb_partial(); break;
	case 0x70: bvs_rel_partial(); break;
	case 0x71: adc_ipx_partial(); break;
	case 0x72: twa_imp_partial(); break;
	case 0x73: nop_c_imp_partial(); break;
	case 0x74: add_zpx_partial(); break;
	case 0x75: adc_c_zpx_partial(); break;
	case 0x76: ror_c_zpx_partial(); break;
	case 0x77: rmb_bzp_partial(); break;
	case 0x78: sei_imp_partial(); break;
	case 0x79: adc_c_aby_partial(); break;
	case 0x7a: ply_imp_partial(); break;
	case 0x7b: jsb_vec_partial(); break;
	case 0x7c: jmp_iax_partial(); break;
	case 0x7d: adc_c_abx_partial(); break;
	case 0x7e: ror_c_abx_partial(); break;
	case 0x7f: bbr_zpb_partial(); break;
	case 0x80: bra_rel_partial(); break;
	case 0x81: sta_zpi_partial(); break;
	case 0x82: nop_imm_partial(); break;
	case 0x83: nop_c_imp_partial(); break;
	case 0x84: sty_zpg_partial(); break;
	case 0x85: sta_zpg_partial(); break;
	case 0x86: stx_zpg_partial(); break;
	case 0x87: smb_bzp_partial(); break;
	case 0x88: dey_imp_partial(); break;
	case 0x89: add_imm_partial(); break;
	case 0x8a: txa_imp_partial(); break;
	case 0x8b: nxt_imp_partial(); break;
	case 0x8c: sty_aba_partial(); break;
	case 0x8d: sta_aba_partial(); break;
	case 0x8e: stx_aba_partial(); break;
	case 0x8f: bbs_zpb_partial(); break;
	case 0x90: bcc_rel_partial(); break;
	case 0x91: sta_ipx_partial(); break;
	case 0x92: nop_imm_partial(); break;
	case 0x93: nop_c_imp_partial(); break;
	case 0x94: sty_zpx_partial(); break;
	case 0x95: sta_zpx_partial(); break;
	case 0x96: stx_zpy_partial(); break;
	case 0x97: smb_bzp_partial(); break;
	case 0x98: tya_imp_partial(); break;
	case 0x99: sta_aby_partial(); break;
	case 0x9a: txs_imp_partial(); break;
	case 0x9b: lii_imp_partial(); break;
	case 0x9c: nop_c_abx_partial(); break;
	case 0x9d: sta_abx_partial(); break;
	case 0x9e: nop_c_abx_partial(); break;
	case 0x9f: bbs_zpb_partial(); break;
	case 0xa0: ldy_imm_partial(); break;
	case 0xa1: lda_zpi_partial(); break;
	case 0xa2: ldx_imm_partial(); break;
	case 0xa3: nop_c_imp_partial(); break;
	case 0xa4: ldy_zpg_partial(); break;
	case 0xa5: lda_zpg_partial(); break;
	case 0xa6: ldx_zpg_partial(); break;
	case 0xa7: smb_bzp_partial(); break;
	case 0xa8: tay_imp_partial(); break;
	case 0xa9: lda_imm_partial(); break;
	case 0xaa: tax_imp_partial(); break;
	case 0xab: lan_imp_partial(); break;
	case 0xac: ldy_aba_partial(); break;
	case 0xad: lda_aba_partial(); break;
	case 0xae: ldx_aba_partial(); break;
	case 0xaf: bbs_zpb_partial(); break;
	case 0xb0: bcs_rel_partial(); break;
	case 0xb1: lda_ipx_partial(); break;
	case 0xb2: sti_imz_partial(); break;
	case 0xb3: nop_c_imp_partial(); break;
	case 0xb4: ldy_zpx_partial(); break;
	case 0xb5: lda_zpx_partial(); break;
	case 0xb6: ldx_zpy_partial(); break;
	case 0xb7: smb_bzp_partial(); break;
	case 0xb8: clv_imp_partial(); break;
	case 0xb9: lda_aby_partial(); break;
	case 0xba: tsx_imp_partial(); break;
	case 0xbb: ini_imp_partial(); break;
	case 0xbc: ldy_abx_partial(); break;
	case 0xbd: lda_abx_partial(); break;
	case 0xbe: ldx_aby_partial(); break;
	case 0xbf: bbs_zpb_partial(); break;
	case 0xc0: cpy_imm_partial(); break;
	case 0xc1: cmp_zpi_partial(); break;
	case 0xc2: rba_ima_partial(); break;
	case 0xc3: nop_c_imp_partial(); break;
	case 0xc4: cpy_zpg_partial(); break;
	case 0xc5: cmp_zpg_partial(); break;
	case 0xc6: dec_c_zpg_partial(); break;
	case 0xc7: smb_bzp_partial(); break;
	case 0xc8: iny_imp_partial(); break;
	case 0xc9: cmp_imm_partial(); break;
	case 0xca: dex_imp_partial(); break;
	case 0xcb: phi_imp_partial(); break;
	case 0xcc: cpy_aba_partial(); break;
	case 0xcd: cmp_aba_partial(); break;
	case 0xce: dec_c_aba_partial(); break;
	case 0xcf: bbs_zpb_partial(); break;
	case 0xd0: bne_rel_partial(); break;
	case 0xd1: cmp_ipx_partial(); break;
	case 0xd2: sba_ima_partial(); break;
	case 0xd3: nop_c_imp_partial(); break;
	case 0xd4: exc_zpx_partial(); break;
	case 0xd5: cmp_zpx_partial(); break;
	case 0xd6: dec_c_zpx_partial(); break;
	case 0xd7: smb_bzp_partial(); break;
	case 0xd8: cld_imp_partial(); break;
	case 0xd9: cmp_aby_partial(); break;
	case 0xda: phx_imp_partial(); break;
	case 0xdb: pli_imp_partial(); break;
	case 0xdc: nop_c_abx_partial(); break;
	case 0xdd: cmp_abx_partial(); break;
	case 0xde: dec_c_abx_partial(); break;
	case 0xdf: bbs_zpb_partial(); break;
	case 0xe0: cpx_imm_partial(); break;
	case 0xe1: sbc_c_zpi_partial(); break;
	case 0xe2: bar_amr_partial(); break;
	case 0xe3: nop_c_imp_partial(); break;
	case 0xe4: cpx_zpg_partial(); break;
	case 0xe5: sbc_c_zpg_partial(); break;
	case 0xe6: inc_c_zpg_partial(); break;
	case 0xe7: smb_bzp_partial(); break;
	case 0xe8: inx_imp_partial(); break;
	case 0xe9: sbc_c_imm_partial(); break;
	case 0xea: nop_imp_partial(); break;
	case 0xeb: lai_imp_partial(); break;
	case 0xec: cpx_aba_partial(); break;
	case 0xed: sbc_c_aba_partial(); break;
	case 0xee: inc_c_aba_partial(); break;
	case 0xef: bbs_zpb_partial(); break;
	case 0xf0: beq_rel_partial(); break;
	case 0xf1: sbc_ipx_partial(); break;
	case 0xf2: bas_amr_partial(); break;
	case 0xf3: nop_c_imp_partial(); break;
	case 0xf4: nop_zpx_partial(); break;
	case 0xf5: sbc_c_zpx_partial(); break;
	case 0xf6: inc_c_zpx_partial(); break;
	case 0xf7: smb_bzp_partial(); break;
	case 0xf8: sed_imp_partial(); break;
	case 0xf9: sbc_c_aby_partial(); break;
	case 0xfa: plx_imp_partial(); break;
	case 0xfb: pia_imp_partial(); break;
	case 0xfc: nop_c_abx_partial(); break;
	case 0xfd: sbc_c_abx_partial(); break;
	case 0xfe: inc_c_abx_partial(); break;
	case 0xff: bbs_zpb_partial(); break;
	case STATE_RESET: reset_r_partial(); break;
	}
}

