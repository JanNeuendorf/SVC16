use crate::engine::MEMSIZE;

#[cfg(feature = "external-expansions")]
use libloading::{Library, Symbol};
#[cfg(feature = "external-expansions")]
use std::ffi::os_str::OsStr;
#[cfg(feature = "external-expansions")]
use std::ffi::{c_void, OsString};
use thiserror::Error;

/// This constant should be incremented, everytime there is:
///
/// 1. an additional expansion method added
/// 2. an expansion method is removed
/// 3. the signature of any expansion method is changed
const API_VERSION: usize = 1;

pub trait Expansion {
    fn api_version(&self) -> usize;
    fn on_init(&mut self);
    fn on_deinit(&mut self);
    fn expansion_triggered(&mut self, buffer: &mut [u16; MEMSIZE]);
}

#[cfg(feature = "external-expansions")]
#[cfg(target_os = "windows")]
type PlatformSymbol<T> = libloading::os::windows::Symbol<T>;
#[cfg(feature = "external-expansions")]
#[cfg(any(target_os = "linux", target_os = "macos"))]
type PlatformSymbol<T> = libloading::os::unix::Symbol<T>;

#[cfg(feature = "external-expansions")]
#[derive(Debug, Error)]
pub enum ExternalExpansionError {
    #[error("Failed to load external expansion \"{path}\"", path = .path.display())]
    FailedToLoadLibrary { path: OsString },

    #[error("Attempted to load external expansion \"{path}\" with incorrect API version. Expected {API_VERSION}, got {api_version}", path = .path.display(), api_version = .api_version)]
    APIVersionMismatch { path: OsString, api_version: usize },

    #[error(
        "Attempted to load external expansion \"{path}\" which is missing required symbol \"{symbol}\"", path = .path.display(), symbol = symbol_name
    )]
    SymbolNotPresent { path: OsString, symbol_name: String },
}

#[cfg(feature = "external-expansions")]
pub struct ExternalExpansion {
    lib: Library,
    initialized: bool,
    sym_api_version: PlatformSymbol<unsafe extern "C" fn() -> usize>,
    sym_on_init: PlatformSymbol<unsafe extern "C" fn() -> c_void>,
    sym_on_deinit: PlatformSymbol<unsafe extern "C" fn() -> c_void>,
    sym_expansion_triggered: PlatformSymbol<unsafe extern "C" fn(&mut [u16; MEMSIZE]) -> c_void>,
}

#[cfg(feature = "external-expansions")]
unsafe fn load_sym<'lib, P: AsRef<OsStr>, T>(
    lib: &'lib Library,
    path: &P,
    name: &[u8],
) -> Result<Symbol<'lib, T>, ExternalExpansionError> {
    lib.get(name)
        .map_err(|_| ExternalExpansionError::SymbolNotPresent {
            path: path.into(),
            symbol_name: String::from_utf8_lossy(name).into_owned(),
        })
}

#[cfg(feature = "external-expansions")]
impl ExternalExpansion {
    pub fn from_lib<P: AsRef<OsStr>>(path: &P) -> Result<Self, ExternalExpansionError> {
        unsafe {
            let lib = Library::new(path).unwrap();
            //.map_err(|_| ExternalExpansionError::FailedToLoadLibrary { path: path.into() })?;

            let sym_api_version: Symbol<unsafe extern "C" fn() -> usize> =
                load_sym(&lib, path, b"svc16_expansion_api_version")?;

            let api_version = sym_api_version();

            if api_version != API_VERSION {
                Err(ExternalExpansionError::APIVersionMismatch {
                    path: path.into(),
                    api_version,
                })
            } else {
                let sym_on_init: Symbol<unsafe extern "C" fn() -> c_void> =
                    load_sym(&lib, path, b"svc16_expansion_on_init")?;
                let sym_on_deinit: Symbol<unsafe extern "C" fn() -> c_void> =
                    load_sym(&lib, path, b"svc16_expansion_on_deinit")?;
                let sym_expansion_triggered: Symbol<
                    unsafe extern "C" fn(&mut [u16; MEMSIZE]) -> c_void,
                > = load_sym(&lib, path, b"svc16_expansion_triggered")?;

                Ok(Self {
                    initialized: false,
                    sym_api_version: sym_api_version.into_raw(),
                    sym_on_init: sym_on_init.into_raw(),
                    sym_on_deinit: sym_on_deinit.into_raw(),
                    sym_expansion_triggered: sym_expansion_triggered.into_raw(),
                    lib,
                })
            }
        }
    }
}

#[cfg(feature = "external-expansions")]
impl Drop for ExternalExpansion {
    fn drop(&mut self) {
        if self.initialized {
            self.on_deinit();
        }
    }
}

#[cfg(feature = "external-expansions")]
impl Expansion for ExternalExpansion {
    fn api_version(&self) -> usize {
        unsafe { (self.sym_api_version)() }
    }
    fn on_init(&mut self) {
        assert!(!self.initialized);
        unsafe {
            (self.sym_on_init)();
        }
    }
    fn on_deinit(&mut self) {
        assert!(self.initialized);
        unsafe {
            (self.sym_on_deinit)();
        }
    }
    fn expansion_triggered(&mut self, buffer: &mut [u16; MEMSIZE]) {
        unsafe {
            (self.sym_expansion_triggered)(buffer);
        }
    }
}
