# Registers

Raw UART and 16C950 ICR registers are exposed under sysfs for low-level
hardware tuning, similar to [fscc-linux registers](https://github.com/commtech/fscc-linux/blob/master/docs/registers.md).

```
/sys/class/serialfc/serialfc*/registers/*
```

Values are hexadecimal. UART and ICR registers are 8-bit (`%02x`). FSCC
`bar2_fcr` is 32-bit (`%08x`).

###### Code Support
| Code | Version |
| ---- | ------- |
| serialfc-linux | HWIL+ |

## Standard UART registers (all card families)

| File | Access | Description |
| ---- | ------ | ----------- |
| `ier` | read/write | Interrupt enable |
| `fcr` | read/write | UART FIFO control (offset 0x2) |
| `lcr` | read/write | Line control |
| `mcr` | read/write | Modem control |
| `lsr` | read-only | Line status |
| `msr` | read-only | Modem status |
| `spr` | read-only | Scratch pad / ICR index (see below) |

### PCI / PCIe only (Exar)

| File | Access | Description |
| ---- | ------ | ----------- |
| `fctr` | read/write | Feature control |
| `txtrg` | read/write* | TX FIFO trigger (write-only hardware) |
| `rxtrg` | read/write* | RX FIFO trigger (write-only hardware) |
| `4xmode` | read/write | 4x sampling mode |
| `8xmode` | read/write | 8x sampling mode |

\* Reads return the driver cache updated by sysfs writes and `settings/tx_trigger` / `settings/rx_trigger`.

## FSCC only — 16C950 ICR registers

These use indexed access (SPR + ICR) inside the driver. Do not write `spr`
directly; it selects which ICR register is targeted.

| File | Access | Description |
| ---- | ------ | ----------- |
| `acr` | read/write | Additional control |
| `tcr` | read/write* | Clock / sample rate (TCR) |
| `cks` | read/write | Clock select |
| `ttl` | read/write* | TX FIFO trigger level |
| `rtl` | read/write* | RX FIFO trigger level |
| `mdm` | read/write | Modem / clock mode helper |
| `ext` | read/write | External transmit low byte |
| `exth` | read/write | External transmit high byte |
| `flr` | read/write | Frame length |

\* Reads return cached driver state for write-only locations.

## FSCC only — BAR2 FCR

| File | Access | Description |
| ---- | ------ | ----------- |
| `bar2_fcr` | read/write | Shared 32-bit FCR on PCI BAR2 |

This is **not** the same as `registers/fcr`:

- `fcr` — UART register at MMIO offset 0x2 on the port
- `bar2_fcr` — card-level register used to enable async UART mode per channel (e.g. `echo 03000000 > .../bar2_fcr` as in the FSCC README)

`bar2_fcr` is **shared across both ports** on the same card.

## Examples

```bash
# Read line control
cat /sys/class/serialfc/serialfc0/registers/lcr

# Set FSCC sample rate via ICR TCR
echo 10 > /sys/class/serialfc/serialfc0/registers/tcr

# Enable FSCC async on port 0 (BAR2 FCR, card-specific bit layout)
echo 03000000 > /sys/class/serialfc/serialfc0/registers/bar2_fcr
```

## Important caveats

### 1. Conflict with the kernel ttyS driver

This driver also registers ports with the kernel `8250` serial core (`/dev/ttyS*`).
The serial core and sysfs both access the same UART MMIO. There is no reliable
kernel API to detect an open tty from this driver, so:

- **Close all `/dev/ttyS*` handles** on the port before writing registers
- Prefer **`settings/`** sysfs attributes or IOCTLs for baud rate, triggers, RS485, etc. when possible
- The driver logs a **one-time warning** on the first register write per port
- A `register_lock` spinlock only serializes sysfs access with itself, **not** with the tty driver

Configure registers before opening the tty port, or after closing it.

### 2. LCR side effects

Writing `lcr` to `0xbf` enters Exar 650 enhanced register mode and remaps
offsets 0x2–0x4. The driver **rejects** `echo bf > .../lcr` via sysfs.

16C950 ICR access always forces `LCR=0` during indexed transactions. Use
`registers/acr`, `registers/tcr`, etc. instead of manipulating `lcr` for ICR work.

Setting `lcr` bit 7 (`0x80`) opens the divisor latch (DLL/DLM). That can
interfere with an open tty session configuring baud rate.

### 3. FSCC `fcr` vs `bar2_fcr`

See the table above. Async mode for FSCC cards is controlled through
`bar2_fcr`, not the UART `fcr` file.

### 4. Permissions

Register files use mode **0660** (`SYSFS_READ_WRITE_MODE`). Root and members
of the device node's group can read/write. Add users to the `dialout` group for
tty access; sysfs permissions follow the `serialfc` device class defaults.

### 5. When to use `settings/` instead

| Goal | Prefer |
| ---- | ------ |
| Baud rate | `settings/baud_rate` |
| Sample rate | `settings/sample_rate` |
| TX/RX triggers | `settings/tx_trigger`, `settings/rx_trigger` |
| RS485 / termination | `settings/rs485`, `settings/termination` |
| FSCC async at boot | `insmod` option `fscc_enable_async=1` or `bar2_fcr` |

Use `registers/` for bit-level work not covered by `settings/` or when
bringing up hardware before the tty layer is in use.