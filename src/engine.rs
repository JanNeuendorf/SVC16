use std::ops::{BitAnd, BitXor};
use thiserror::Error;

use crate::expansions::Expansion;

pub const MEMSIZE: usize = u16::MAX as usize + 1;

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
const DEBUG: u16 = 10;
const PRINT: u16 = 11;
const READ: u16 = 12;
const BAND: u16 = 13;
const XOR: u16 = 14;
const SYNC: u16 = 15;

// The goal is to eventually stabilize the api for the Engine so it can be easily reused in different emulators.
// This has to be postponed until the first expansions are implemented and tested.
pub struct Engine {
    memory: Box<[u16; MEMSIZE]>,
    screen_buffer: Box<[u16; MEMSIZE]>,
    utility_buffer: Box<[u16; MEMSIZE]>,
    utility_back_buffer: Box<[u16; MEMSIZE]>,
    expansion: Option<Box<dyn Expansion>>,
    instruction_pointer: u16,
    //These are the addreses that the input should be written to (as requested by Sync).
    pos_code_dest: u16,
    key_code_dest: u16,
    sync_called: bool,
    expansion_triggered: bool,
}

#[derive(Debug, Error)]
pub enum EngineError {
    #[error("Division by zero {0}/0")]
    ZeroDivision(u16),

    #[error("Invalid instruction {0}")]
    InvalidInstruction(u16),
}

impl Engine {
    pub fn new<T>(state: T, mut expansion: Option<Box<dyn Expansion>>) -> Self
    where
        T: IntoIterator<Item = u16>,
        //The iterator can be shorter, in which case the rest of the memory is left as zeros.
        //If it is longer, the end is never read.
    {
        let iter = state.into_iter();
        let mut memory = vec![0; MEMSIZE];
        for (cell, val) in memory.iter_mut().zip(iter) {
            *cell = val;
        }

        if let Some(expansion) = expansion.as_mut() {
            expansion.on_init();
        }

        Self {
            memory: memory
                .try_into()
                .expect("failed to convert memory into boxed array"),
            screen_buffer: vec![0; MEMSIZE]
                .try_into()
                .expect("failed to convert screen buffer into boxed array"),
            utility_back_buffer: vec![0; MEMSIZE]
                .try_into()
                .expect("failed to convert screen buffer into boxed array"),
            utility_buffer: vec![0; MEMSIZE]
                .try_into()
                .expect("failed to convert screen buffer into boxed array"),
            expansion,
            instruction_pointer: 0,
            pos_code_dest: 0,
            key_code_dest: 0,
            sync_called: false,
            expansion_triggered: false,
        }
    }
    pub fn wants_to_sync(&self) -> bool {
        self.sync_called
    }
    pub fn set_input(&mut self, pos_code: u16, key_code: u16) {
        self.set(self.pos_code_dest, pos_code);
        self.set(self.key_code_dest, key_code);
    }
    pub fn perform_sync(
        &mut self,
        pos_code: u16,
        key_code: u16,
        screen_buffer_destination: &mut [u16],
    ) {
        screen_buffer_destination.copy_from_slice(&*self.screen_buffer);
        if self.sync_called {
            self.sync_called = false;
            self.set_input(pos_code, key_code);
        }
        // Even if no expansion is active, triggering the mechanism must still clear the utility buffer.
        if self.expansion_triggered {
            if let Some(expansion) = self.expansion.as_mut() {
                expansion.expansion_triggered(&mut self.utility_back_buffer);
                self.utility_back_buffer
                    .swap_with_slice(&mut self.utility_buffer[..]);
            } else {
                self.utility_back_buffer.fill(0);
                self.utility_buffer.fill(0);
            }
            self.expansion_triggered = false;
        }
    }
}
impl Engine {
    // Public for debugging.
    pub fn get(&self, index: u16) -> u16 {
        self.memory[index as usize]
    }
    fn set(&mut self, index: u16, value: u16) {
        self.memory[index as usize] = value;
    }
    fn get_screen_buffer(&self, index: u16) -> u16 {
        self.screen_buffer[index as usize]
    }
    fn get_utility_buffer(&self, index: u16) -> u16 {
        self.utility_buffer[index as usize]
    }
    fn set_screen_buffer(&mut self, index: u16, value: u16) {
        self.screen_buffer[index as usize] = value;
    }
    fn set_utility_buffer(&mut self, index: u16, value: u16) {
        self.utility_buffer[index as usize] = value;
    }
    pub fn read_instruction(&self) -> [u16; 4] {
        let inst_ptr = self.instruction_pointer;
        [
            self.get(inst_ptr.wrapping_add(0)),
            self.get(inst_ptr.wrapping_add(1)),
            self.get(inst_ptr.wrapping_add(2)),
            self.get(inst_ptr.wrapping_add(3)),
        ]
    }
    fn advance_inst_ptr(&mut self) {
        self.instruction_pointer = self.instruction_pointer.wrapping_add(4);
    }
    pub fn step(&mut self) -> Result<Option<(u16, u16, u16)>, EngineError> {
        let [opcode, arg1, arg2, arg3] = self.read_instruction();
        match opcode {
            SET => {
                let value = match arg3 {
                    0 => arg2,
                    _ => self.instruction_pointer,
                };
                self.set(arg1, value);
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
                    let numerator = self.get(arg1);
                    return Err(EngineError::ZeroDivision(numerator));
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
            DEBUG => {
                let label = arg1;
                let value1 = self.get(arg2);
                let value2 = self.get(arg3);
                self.advance_inst_ptr();
                return Ok(Some((label, value1, value2)));
            }
            PRINT => {
                if arg3 == 0 {
                    self.set_screen_buffer(self.get(arg2), self.get(arg1));
                } else {
                    self.set_utility_buffer(self.get(arg2), self.get(arg1));
                }
                self.advance_inst_ptr();
            }
            READ => {
                if arg3 == 0 {
                    self.set(arg2, self.get_screen_buffer(self.get(arg1)));
                } else {
                    self.set(arg2, self.get_utility_buffer(self.get(arg1)));
                }
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
                self.pos_code_dest = arg1;
                self.key_code_dest = arg2;
                if arg3 > 0 {
                    self.expansion_triggered = true;
                }
                self.advance_inst_ptr();
            }
            _ => return Err(EngineError::InvalidInstruction(opcode)),
        }
        Ok(None)
    }
}
