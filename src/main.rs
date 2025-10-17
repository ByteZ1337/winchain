#![no_main]
#![no_std]

extern crate alloc;

use alloc::vec;
use log::{error, info};
use uefi::boot::{LoadImageSource, OpenProtocolAttributes, OpenProtocolParams, SearchType};
use uefi::prelude::*;
use uefi::proto::media::partition::{PartitionInfo, PartitionType};
use uefi::{CStr16, Guid, Identify};
use uefi::proto::BootPolicy;
use uefi::proto::device_path::build::{DevicePathBuilder};
use uefi::proto::device_path::build::media::FilePath;
use uefi::proto::device_path::DevicePath;

const BOOTLOADER_PATH: &CStr16 = cstr16!(r"\EFI\Microsoft\Boot\bootmgfw.efi");

const TARGET_GUID: Guid = get_target_guid();

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();

    let handles = match boot::locate_handle_buffer(SearchType::ByProtocol(&PartitionInfo::GUID)) {
        Ok(buf) => buf,
        Err(err) => {
            error!("Failed to locate handles: {err}");
            return Status::NOT_FOUND;
        }
    };
    let image = boot::image_handle();

    for handle in handles.iter() {
        let pinfo_proto = match unsafe {
            boot::open_protocol::<PartitionInfo>(
                OpenProtocolParams {
                    handle: *handle,
                    agent: image,
                    controller: None,
                },
                OpenProtocolAttributes::GetProtocol,
            )
        } {
            Ok(proto) => proto,
            Err(err) => {
                error!("Failed to open PartitionInfo protocol: {err}",);
                continue;
            }
        };

        // can't inline cause of unaligned packed struct
        let ty = pinfo_proto.partition_type;
        if ty != PartitionType::GPT {
            continue;
        }

        let gpt = match pinfo_proto.gpt_partition_entry() {
            Some(entry) => entry,
            None => continue,
        };

        let guid = gpt.unique_partition_guid;
        if guid != TARGET_GUID {
            continue;
        }

        // found the target partition
        let dp_proto = match unsafe {
            boot::open_protocol::<DevicePath>(
                OpenProtocolParams {
                    handle: *handle,
                    agent: image,
                    controller: None,
                },
                OpenProtocolAttributes::GetProtocol,
            )
        } {
            Ok(proto) => proto,
            Err(err) => {
                error!("Failed to open DevicePath protocol for {guid}: {err}");
                return err.status();
            }
        };
        let mut buffer = vec![0u8; 128];
        let mut builder = DevicePathBuilder::with_vec(&mut buffer);
        for node in dp_proto.node_iter() {
            builder = match builder.push(&node) {
                Ok(builder) => builder,
                Err(err) => {
                    error!("Failed to build device path: {err}");
                    return Status::LOAD_ERROR;
                }
            };
        }
        let path = match builder.push(&FilePath {
            path_name: BOOTLOADER_PATH,
        }).and_then(|b| b.finalize()) {
            Ok(b) => b,
            Err(err) => {
                error!("Failed to finalize path: {err}");
                return Status::LOAD_ERROR;
            }
        };

        let win_handle = match boot::load_image(
            image,
            LoadImageSource::FromDevicePath {
                device_path: &path,
                boot_policy: BootPolicy::ExactMatch
            },
        ) {
            Ok(handle) => handle,
            Err(err) => {
                error!("Failed to load image {BOOTLOADER_PATH} on {guid}: {err}");
                return err.status();
            }
        };

        let status = boot::start_image(win_handle);
        return match status {
            Ok(_) => Status::SUCCESS,
            Err(err) => err.status(),
        };
    }

    Status::NOT_FOUND
}

const fn get_target_guid() -> Guid {
    let guid = env!("WINCHAIN_BOOT_PARTITION_GUID");
    let b = guid.as_bytes();
    if b.len() != 36 {
        panic!("Invalid GUID length");
    }

    // time_low
    let t0 = hex_byte(b[0], b[1]);
    let t1 = hex_byte(b[2], b[3]);
    let t2 = hex_byte(b[4], b[5]);
    let t3 = hex_byte(b[6], b[7]);
    // time_mid
    let m0 = hex_byte(b[9], b[10]);
    let m1 = hex_byte(b[11], b[12]);
    // time_high
    let h0 = hex_byte(b[14], b[15]);
    let h1 = hex_byte(b[16], b[17]);
    // clock seq
    let c0 = hex_byte(b[19], b[20]);
    let c1 = hex_byte(b[21], b[22]);
    // node
    let n0 = hex_byte(b[24], b[25]);
    let n1 = hex_byte(b[26], b[27]);
    let n2 = hex_byte(b[28], b[29]);
    let n3 = hex_byte(b[30], b[31]);
    let n4 = hex_byte(b[32], b[33]);
    let n5 = hex_byte(b[34], b[35]);

    Guid::new(
        [t3, t2, t1, t0],
        [m1, m0],
        [h1, h0],
        c0,
        c1,
        [n0, n1, n2, n3, n4, n5],
    )
}

const fn hex_val(c: u8) -> u8 {
    match c {
        b'0'..=b'9' => c - b'0',
        b'a'..=b'f' => 10 + (c - b'a'),
        b'A'..=b'F' => 10 + (c - b'A'),
        _ => panic!("Invalid hex character in GUID"),
    }
}
const fn hex_byte(hi: u8, lo: u8) -> u8 {
    (hex_val(hi) << 4) | hex_val(lo)
}
