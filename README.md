# husearch

> Servis farkındalığı olan, modüler sızma testi keşif aracı — `rustscan` + `nmap` + akıllı servis analizi + opsiyonel AI pentester yorumu.

`husearch`, bir hedefe karşı port keşfini, servis/versiyon tespitini ve servise özel enumeration önerilerini tek komutta toplayan bir Bash aracıdır. Tüm portları hızlıca `rustscan` ile tarar, açık portları `nmap` ile derinlemesine analiz eder, bulduğu servislere göre (SMB, HTTP, FTP, SSH, Redis, SNMP, MySQL, LDAP, Kerberos...) somut sonraki adımları önerir ve — isteğe bağlı — bulguları Claude'a gönderip uzman seviyesinde bir saldırı yolu yorumu üretir.

> ⚠️ **Yalnızca yetkili kullanım için.** Bu araç; sahibi olduğunuz sistemlerde, yazılı izni olan sızma testlerinde, CTF/lab ortamlarında (HTB, THM, PG vb.) ve güvenlik eğitiminde kullanılmak üzere tasarlanmıştır. İzniniz olmayan sistemleri taramak çoğu ülkede suçtur. Sorumluluk tamamen kullanıcıya aittir.

## İçindekiler

- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
- [Tarama profilleri](#tarama-profilleri)
- [Enumeration modları](#enumeration-modları)
- [AI pentester analizi](#ai-pentester-analizi)
- [Çıktılar](#çıktılar)
- [Örnekler](#örnekler)
- [Nasıl çalışır](#nasıl-çalışır)
- [SSS](#sss)
- [Lisans](#lisans)

## Özellikler

- **Üç tarama profili** — `quick` (1–1000 port, hızlı), `full` (tüm portlar + script, varsayılan), `deep` (vuln scriptleri + UDP top-30).
- **Dayanıklı port keşfi** — `rustscan` retry mantığı, sonuç gelmezse otomatik `nmap -p-` fallback. Paket kaybı olan bağlantılarda bile çalışır.
- **Akıllı servis analizi** — açık her servis için servise özel enumeration komutları ve ipuçları (SMB, HTTP(S), FTP, SSH, SNMP, Redis, MySQL/MSSQL/Mongo, RDP, LDAP, SMTP, DNS, Kerberos, NFS/RPC, VNC, Telnet, Memcached, Java RMI...).
- **Versiyon bazlı zafiyet ihbarı** — tespit edilen servis versiyonlarını bilinen CVE'lerle eşler (vsftpd 2.3.4, ProFTPD mod_copy, Apache 2.4.49/50, libssh auth bypass, OpenSSH kullanıcı enum, Drupalgeddon, regreSSHion ve daha fazlası).
- **Güvenli enum kontrolleri** — SMB null session, anonymous FTP, HTTP banner/robots.txt, Redis yetkisiz erişim, SNMP `public` community testlerini otomatik (veya `--ask` ile onaylı) çalıştırır. Yalnızca okuma amaçlı, yıkıcı olmayan kontroller.
- **AI pentester analizi** — `ANTHROPIC_API_KEY` tanımlıysa bulguları Claude'a gönderir; özet, güven etiketli olası CVE'ler, öncelikli saldırı yolu ve kopyala-çalıştır komutlar üretir (tamamen Türkçe).
- **JSON çıktı** — nmap XML'i ayrıştırıp programatik işleme için temiz bir JSON üretir.
- **Tarama karşılaştırması** — aynı hedefin önceki taramasıyla diff: yeni açılan / kapanan portlar ve servis değişiklikleri.

## Gereksinimler

Zorunlu:

| Araç | Kurulum (Debian/Kali/Ubuntu) |
|------|------------------------------|
| `rustscan` | [rustscan sürümleri](https://github.com/bee-san/RustScan/releases) · `cargo install rustscan` |
| `nmap` | `sudo apt install -y nmap` |
| `python3` | `sudo apt install -y python3` |

İsteğe bağlı (ilgili enum kontrolleri ve öneriler için): `smbclient`, `curl`, `snmpwalk`, `redis-cli`, ve genel pentest araç seti (`enum4linux`, `gobuster`, `nikto`, `whatweb`, `wpscan` vb.). Kurulu değillerse ilgili adım atlanır, araç çalışmaya devam eder.

> Kali Linux kullanıyorsanız `nmap`, `python3`, `smbclient`, `curl`, `snmpwalk`, `redis-cli` çoğunlukla hazır gelir; yalnızca `rustscan` eklemeniz yeterli olabilir.

## Kurulum

```bash
git clone https://github.com/sadecehus/husearch.git
cd husearch
./install.sh
```

`install.sh`, `husearch`'i `~/.local/bin` altına kopyalar ve çalıştırılabilir yapar. `~/.local/bin` `PATH`'inizde değilse script sizi uyarır.

Elle kurulum:

```bash
install -m 755 husearch ~/.local/bin/husearch
# veya sistem geneli:
sudo install -m 755 husearch /usr/local/bin/husearch
```

Kurulumu doğrulayın:

```bash
husearch --help
```

## Kullanım

```
husearch <ip> [seçenekler] [ekstra nmap argümanları]
```

Flagsiz `husearch <ip>` = **yardımcı pentester modu**: `full` profil + otomatik güvenli enum + (API key varsa) AI analizi.

```
Seçenekler:
  -p quick|full|deep   tarama profili (varsayılan: full)
  -u, --udp            UDP top-30 taraması ekle (deep zaten içerir)
  --ask                enum kontrollerinden önce onay sor
  --no-enum            enum kontrollerini atla (sadece öneri göster)
  --no-ai              AI pentester analizini atla
  --no-json            JSON çıktı üretme
  --no-diff            önceki tarama ile karşılaştırmayı atla
  -h, --help           yardım
```

Tanınmayan argümanlar doğrudan `nmap`'e geçirilir — ör. `--script vuln -T5`.

## Tarama profilleri

| Profil | Portlar | nmap bayrakları | Notlar |
|--------|---------|-----------------|--------|
| `quick` | 1–1000 | `-sV --version-light` | Hızlı ön keşif |
| `full` *(varsayılan)* | 0–65535 | `-sV -sC` | Dengeli; varsayılan script seti |
| `deep` | 0–65535 | `-sV -sC --script vuln` + UDP top-30 | En kapsamlı; **root gerekir**, uzun sürer |

## Enumeration modları

- **auto** *(varsayılan, flagsiz çalışınca)* — güvenli enum kontrollerini otomatik çalıştırır.
- **ask** (`--ask`) — her enum kontrolünden önce `[y/N]` onayı ister.
- **off** (`--no-enum`) — hiçbir aktif kontrol yapmaz, yalnızca önerileri listeler.

Enum kontrolleri yalnızca okuma amaçlı ve yıkıcı değildir (null session listesi, anonymous FTP listesi, HTTP başlık/robots, Redis `INFO`, SNMP `public`).

## AI pentester analizi

`ANTHROPIC_API_KEY` tanımlıysa, tarama bulguları Claude'a gönderilir ve kıdemli bir pentester bakış açısıyla yorumlanır. Sistem talimatı; uydurma CVE üretmemeyi, yalnızca kanıta dayanmayı ve yıkıcı/DoS tekniği önermemeyi açıkça zorunlu kılar.

```bash
export ANTHROPIC_API_KEY=sk-ant-...
# isteğe bağlı:
export HUSEARCH_MODEL=claude-opus-4-8     # varsayılan
export HUSEARCH_EFFORT=medium             # low|medium|high|xhigh|max
```

> API anahtarınızı repoya veya kabuk geçmişinize yazmayın. `~/.bashrc`/`~/.zshrc` içinde ya da bir gizli ortam dosyasında tutun. AI'yi tamamen kapatmak için `--no-ai` kullanın.

AI çıktısı ayrıca `~/husearch-results/<ip>_<zaman>.ai.md` olarak kaydedilir.

## Çıktılar

Tüm sonuçlar `~/husearch-results/` altına `<ip>_<zaman>` ön ekiyle yazılır:

| Dosya | İçerik |
|-------|--------|
| `.nmap` | nmap insan-okur çıktısı |
| `.xml` | nmap XML (programatik) |
| `.json` | ayrıştırılmış birleşik sonuç (portlar, bulgular, öneriler, diff) |
| `.udp.nmap` / `.udp.xml` | UDP taraması (yalnızca `-u`/`deep`) |
| `.ai.md` | AI pentester analizi (yalnızca API key varsa) |

## Örnekler

```bash
# Varsayılan: full profil + otomatik enum + (varsa) AI
husearch 10.10.10.5

# Hızlı ön keşif, onaylı enum
husearch 10.10.10.5 -p quick --ask

# Derin tarama (vuln scriptleri + UDP), root ile
sudo husearch 10.10.10.5 -p deep

# Ekstra nmap argümanları geçir
husearch 10.10.10.5 -p quick --script vuln -T5

# AI ve JSON olmadan, sadece öneriler
husearch 10.10.10.5 --no-ai --no-json --no-enum
```

## Nasıl çalışır

1. **Port keşfi** — `rustscan` ile hızlı tarama (retry'lı); sonuç gelmezse `nmap -p-` fallback.
2. **Servis taraması** — açık portlarda profil'e göre `nmap -sV -sC` (ve gerekirse `--script vuln`).
3. **UDP** *(opsiyonel)* — `nmap -sU --top-ports 30`.
4. **Akıllı analiz** — nmap çıktısı ayrıştırılır; her servis için modül çalışır, versiyon ipuçları ve enum önerileri üretir.
5. **Diff** — aynı hedefin önceki taramasıyla karşılaştırma.
6. **JSON** — Python ile nmap XML → JSON.
7. **AI analizi** *(opsiyonel)* — bulgular Claude API'ye gönderilir.
8. **Özet** — bulgular, öneri sayısı, süre ve dosya yolları.

## SSS

**`rustscan bulunamadı` hatası alıyorum.**
`rustscan`'i [GitHub sürümlerinden](https://github.com/bee-san/RustScan/releases) ya da `cargo install rustscan` ile kurun; `PATH`'inizde olduğundan emin olun.

**UDP taraması çalışmıyor.**
UDP ham soket gerektirir; `sudo husearch ... -u` ya da `-p deep` ile root olarak çalıştırın.

**AI analizi hep atlanıyor.**
`ANTHROPIC_API_KEY` tanımlı değildir ya da `curl` kurulu değildir. Anahtarı export edin veya `--no-ai` ile sessizce geçin.

**nmap hata koduyla çıkıyor.**
Root değilken bazı tarama türleri sınırlıdır. SYN taraması için `sudo` ile çalıştırın.

## Lisans

[MIT](LICENSE) © sadecehus
