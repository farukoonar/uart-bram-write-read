# UART Controlled Block RAM (BRAM) Read/Write Interface

**[TR]** Digilent Basys 3 FPGA kartı üzerinde UART protokolü üzerinden Blok RAM (BRAM) modülüne 16-bit veri yazmayı ve okumayı sağlayan, FSM tabanlı, paket protokolü destekli ve self-checking testbench ile doğrulanmış tam senkron bellek denetleyicisi tasarımı.  
**[EN]** A fully synchronous Block RAM (BRAM) controller core on Basys 3 FPGA, providing 16-bit read/write access over a packetized UART protocol with FSM control and verified via a self-checking testbench.

---

## Temel Özellikler / Key Features

**[TR]**
* **Parametrik Bellek:** 16-bit veri genişliği (`RAM_WIDTH = 16`), 128 adres derinliği (`RAM_DEPTH = 128`) ve düşük gecikme (`LOW_LATENCY`).
* **Paket Tabanlı İletişim:** 4 baytlık çerçeve yapısıyla kararlı veri ve komut aktarımı.
* **Self-Checking Testbench:** VHDL `procedure` mimarisi ve otomatik doğrulama ile konsoldan anlık test onayı.
* **Donanım Doğrulaması:** Basys 3 kartı üzerinde HTerm seri port arayüzü ile gerçek zamanlı yazma/okuma testi.

**[EN]**
* **Parametric Memory:** 16-bit data width (`RAM_WIDTH = 16`), 128 depth (`RAM_DEPTH = 128`), and low latency (`LOW_LATENCY`).
* **Packet-Based Communication:** Fixed 4-byte frame structure for reliable command and data transfer.
* **Self-Checking Testbench:** Automated pass/fail verification directly in the simulator console using VHDL procedures.
* **Hardware Verification:** Real-time write/read validation on Basys 3 FPGA using the HTerm serial terminal.

---

## UART İletişim Protokolü / UART Communication Protocol

**[TR]** Bilgisayar ile FPGA arasındaki haberleşme **4 baytlık paketler** halinde gerçekleşir:  
**[EN]** Host PC and FPGA communicate through fixed **4-byte frames**:

| Bayt No / Byte Index | Alan / Field | Açıklama (TR) | Description (EN) |
| :---: | :---: | :--- | :--- |
| **Byte 1** | **Opcode** | `0x0A` (Yazma / WRITE) veya `0x0B` (Okuma / READ) | `0x0A` for WRITE, `0x0B` for READ |
| **Byte 2** | **Address** | Hedef BRAM Adresi (0 - 127) | Target BRAM Address (0 - 127) |
| **Byte 3** | **Data (MSB)** | Yazılacak verinin üst baytı (Okumada dummy: `0x00`) | Write data high byte (Dummy `0x00` during READ) |
| **Byte 4** | **Data (LSB)** | Yazılacak verinin alt baytı (Okumada dummy: `0x00`) | Write data low byte (Dummy `0x00` during READ) |

### Komut Örnekleri / Command Examples:
* **Yazma / WRITE (`0x0A`):** `0x0A` - `0x05` - `0x11` - `0x22`  
  * **[TR]** Adres `0x05`'e `0x1122` verisini yazar.
  * **[EN]** Writes `0x1122` into address `0x05`.
* **Okuma / READ (`0x0B`):** `0x0B` - `0x05` - `0x00` - `0x00`  
  * **[TR]** Adres `0x05`'teki veriyi okur; FPGA `tx_o` hattından sırasıyla `0x11` ve `0x22` baytlarını geri basar.
  * **[EN]** Reads address `0x05`; FPGA streams back `0x11` (MSB) followed by `0x22` (LSB).

---

## Sistem Mimarisi ve FSM / System Architecture & FSM
### 1. Sistem Blok Diyagramı / System Block Diagram

<p align="center">
<img width="1437" height="419" alt="image" src="https://github.com/user-attachments/assets/56fb590a-b972-4ba2-8292-86c0050447eb" />
</p>

---

### 2. Durum Makinesi (FSM) Mimarisi / State Machine Architecture

**[TR]** Sistemin kontrol mantığı 4 ana durumdan oluşmaktadır:
* **`S_IDLE`:** UART RX hattından 4 baytlık paket tamamlanana kadar verileri kaydırma register'ına alır.
* **`S_WRITE`:** BRAM'e 1 saat çevrimlik senkron `wea = '1'` darbesi üreterek veriyi ilgili adrese yazar.
* **`S_READ`:** Adresi BRAM'e uygular ve senkron bellek okuma gecikmesini bekler.
* **`S_TRANS`:** Okunan 16-bit veriyi iki parçaya bölerek her baytı UART TX üzerinden seri hatta basar.

**[EN]** The control logic consists of 4 main states:
* **`S_IDLE`:** Shifts incoming bytes from UART RX until a complete 4-byte packet is formed.
* **`S_WRITE`:** Commits data to the addressed location using a single-cycle synchronous `wea = '1'` pulse.
* **`S_READ`:** Applies address to BRAM and waits for synchronous memory read latency.
* **`S_TRANS`:** Splits the 16-bit word into two bytes and serializes them sequentially over UART TX.

<p align="center">
<img width="1144" height="976" alt="image" src="https://github.com/user-attachments/assets/7211c396-e40a-43ff-92d2-d6ec7b3eed8f" />
</p>

---

## Simülasyon ve Doğrulama / Simulation & Verification

Tasarım Vivado Simulator üzerinde hem dalga şekli seviyesinde hem de otomatik konsol raporlama mekanizmasıyla test edilmiştir:  
*(The design was verified in Vivado Simulator via both waveform timing analysis and an automated self-checking testbench):*

### 1. Dalga Şekli Analizi / Waveform Analysis:
**[TR]** Adres `0x05`'e `0x1122` ve Adres `0x25`'e `0x0960` yazılıp okunması senaryoları:  
**[EN]** Scenarios for writing and reading `0x1122` at address `0x05` and `0x0960` at address `0x25`:

<img width="2560" height="502" alt="image" src="https://github.com/user-attachments/assets/effc23ab-7e8e-48c4-94d5-7e64908b7c32" />


> **Zamanlama Analizi / Timing Analysis:**
> * **[TR]** `addr`, `dwrite` ve `dread` sinyalleri BRAM gecikmesine tam uyumlu çalışmaktadır. `tx_start` sinyalinin her bayt iletimi için tam 1 clock genişliğinde darbe ürettiği ve `din` hattından sırasıyla `MSB` ve `LSB` verilerinin aktığı doğrulanmıştır.
> * **[EN]** `addr`, `dwrite`, and `dread` buses operate synchronously with BRAM latency. `tx_start` generates clean 1-cycle pulses per byte, transferring `MSB` and `LSB` data sequentially on `din`.

### 2. Otomatik Testbench Doğrulaması / Self-Checking Testbench:
**[TR]** Testbench içine yerleştirilen `uart_rx` alıcı modeli sayesinde gelen veriler otomatik olarak yakalanmış ve beklenen verilerle karşılaştırılmıştır:  
**[EN]** A companion `uart_rx` receiver model inside the testbench captures returned serial bytes and validates them against expected values:

<img width="1600" height="127" alt="WhatsApp Image 2026-10-09 at 11 53 02 PM" src="https://github.com/user-attachments/assets/2b640e9a-90a2-412e-a9c3-4b67e2466306" />

---

## Donanım Doğrulaması (FPGA Demo) / Hardware Verification

**[TR]** Proje **Digilent Basys 3 (Artix-7)** geliştirme kartına yüklenmiş ve bilgisayar üzerinden **HTerm** seri port programı ile 115200 baud hızında canlı olarak test edilmiştir. HTerm üzerinden gönderilen 4 baytlık paketler ile RAM'e yazma yapılmış ve okuma komutu sonucunda doğru verilerin geri geldiği kart üzerinde gözlemlenmiştir.  
**[EN]** Programmed onto the **Digilent Basys 3 (Artix-7)** FPGA board and verified in real time using the **HTerm** terminal at 115200 baud. 4-byte command frames write data into BRAM, and subsequent read commands return the correct 16-bit words back to the terminal.

[uart-bram.webm](https://github.com/user-attachments/assets/424191e6-968a-46b7-83bf-2ff9ec8618cf)

---

## Proje Klasör Yapısı / Project Structure

```text
├── rtl/
│   ├── top.vhd          # Ana FSM ve Entegrasyon Modülü / Top-level FSM & integration
│   ├── block_ram.vhd    # Parametrik Blok RAM Çekirdeği / Parametric Block RAM core
│   ├── ram_pkg.vhd      # clogb2 ve yardımcı fonksiyon paketi / Package & helper functions
│   ├── uart_rx.vhd      # UART Alıcı Modülü / UART Receiver core
│   └── uart_tx.vhd      # UART Verici Modülü / UART Transmitter core
├── tb/
│   └── tb_top.vhd       # Modüler Self-Checking Testbench / Modular self-checking testbench
└── README.md
