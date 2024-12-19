use std::ops::{BitAnd, BitXor};
use thiserror::Error;

const MEMSIZE: usize = u16::MAX as usize + 1;

const SET: u16 = 0;
const GOTO: u16 = 1;
const SKIP: u16 = 2;
const ADD: u16 = 3;
const SUB: u16 = 4;
const MUL: u16 = 5;
const DIV: u16 = 6;
const CMP: u16 = 7;
const DEREF: u16 = 8;
const REF: u16 = 9;
const INST: u16 = 10;
const PRINT: u16 = 11;
const READ: u16 = 12;
const BAND: u16 = 13;
const XOR: u16 = 14;
const SYNC: u16 = 15;

pub struct Engine {
    memory: [u16; MEMSIZE],
    screen: [u16; MEMSIZE],
    instruction_pointer: u16,
    pos_code: u16,
    key_code: u16,
    sync_called: bool,
}

#[derive(Debug, Error)]
pub enum EngineError {
    #[error("Division by zero")]
    ZeroDivision,

    #[error("Invalid instruction")]
    InvalidInstruction,
}

impl Engine {
    pub fn new<T>(state: T) -> Self
    where
        T: IntoIterator<Item = u16>,
    {
        let mut iter = state.into_iter();
        let mut memory = [0_u16; MEMSIZE];
        for i in 0..MEMSIZE {
            match iter.next() {
                Some(val) => {
                    memory[i] = val;
                }
                _ => {
                    break;
                }
            }
        }
        Self {
            memory,
            screen: [0; MEMSIZE],
            instruction_pointer: 0,
            pos_code: 0,
            key_code: 0,
            sync_called: false,
        }
    }
    pub fn wants_to_sync(&self) -> bool {
        return self.sync_called;
    }
    pub fn set_input(&mut self, pos_code: u16, key_code: u16) {
        self.pos_code = pos_code;
        self.key_code = key_code;
    }
    pub fn perform_sync(&mut self, pos_code: u16, key_code: u16) -> [u16; MEMSIZE] {
        self.set_input(pos_code, key_code);
        self.sync_called = false;
        return self.screen.clone();
    }
}
impl Engine {
    pub fn get(&self, index: u16) -> u16 {
        return self.memory[index as usize];
    }
    fn set(&mut self, index: u16, value: u16) {
        self.memory[index as usize] = value;
    }
    fn get_screen(&self, index: u16) -> u16 {
        return self.screen[index as usize];
    }
    fn set_screen(&mut self, index: u16, value: u16) {
        self.screen[index as usize] = value;
    }
    pub fn read_instruction(&self) -> [u16; 4] {
        return [0, 1, 2, 3].map(|o| self.get(self.instruction_pointer.wrapping_add(o)));
    }
    fn advance_inst_ptr(&mut self) {
        self.instruction_pointer = self.instruction_pointer.wrapping_add(4);
    }
    pub fn step(&mut self) -> Result<(), EngineError> {
        let [opcode, arg1, arg2, arg3] = self.read_instruction();
        match opcode {
            SET => {
                self.set(arg1, arg2);
                self.advance_inst_ptr();
            }
            GOTO => {
                if self.get(arg3) == 0 {
                    self.instruction_pointer = self.get(arg1).wrapping_add(arg2);
                } else {
                    self.advance_inst_ptr();
                }
            }
            SKIP => {
                if self.get(arg3) == 0 {
                    self.instruction_pointer = self
                        .instruction_pointer
                        .wrapping_add(arg1.wrapping_mul(4).wrapping_sub(arg2.wrapping_mul(4)));
                } else {
                    self.advance_inst_ptr();
                }
            }
            ADD => {
                self.set(arg3, self.get(arg1).wrapping_add(self.get(arg2)));
                self.advance_inst_ptr();
            }
            SUB => {
                self.set(arg3, self.get(arg1).wrapping_sub(self.get(arg2)));
                self.advance_inst_ptr();
            }
            MUL => {
                self.set(arg3, self.get(arg1).wrapping_mul(self.get(arg2)));
                self.advance_inst_ptr();
            }
            DIV => {
                if self.get(arg2) == 0 {
                    return Err(EngineError::ZeroDivision);
                } else {
                    self.set(arg3, self.get(arg1).wrapping_div(self.get(arg2)));
                    self.advance_inst_ptr();
                }
            }
            CMP => {
                if self.get(arg1) < self.get(arg2) {
                    self.set(arg3, 1);
                } else {
                    self.set(arg3, 0);
                }
                self.advance_inst_ptr();
            }
            DEREF => {
                let value = self.get(self.get(arg1) + arg3);
                self.set(arg2, value);
                self.advance_inst_ptr();
            }
            REF => {
                let value = self.get(arg2);
                self.set(self.get(arg1) + arg3, value);
                self.advance_inst_ptr();
            }
            INST => {
                let value = self.instruction_pointer;
                self.set(arg1, value);
                self.advance_inst_ptr();
            }
            PRINT => {
                self.set_screen(self.get(arg2), self.get(arg1));
                self.advance_inst_ptr();
            }
            READ => {
                self.set(arg2, self.get_screen(self.get(arg1)));
                self.advance_inst_ptr();
            }
            BAND => {
                let band = self.get(arg1).bitand(self.get(arg2));
                self.set(arg3, band);
                self.advance_inst_ptr();
            }
            XOR => {
                let xor = self.get(arg1).bitxor(self.get(arg2));
                self.set(arg3, xor);
                self.advance_inst_ptr();
            }
            SYNC => {
                self.sync_called = true;
                self.set(arg1, self.pos_code);
                self.set(arg2, self.key_code);
                self.advance_inst_ptr();
            }
            _ => return Err(EngineError::InvalidInstruction),
        }
        Ok(())
    }
}
