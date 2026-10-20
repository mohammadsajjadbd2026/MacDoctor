# MacDoctor 🩺 — আপনার MacBook-এর স্বয়ংক্রিয় ডাক্তার

**MacBook Pro 2017** (i7, 16 GB RAM, 1 TB) সহ যেকোনো Intel Mac-এর সফটওয়্যার ও macOS-এর
সমস্যা নিজে নিজে খুঁজে বের করে এবং যেগুলো নিরাপদে ঠিক করা যায় সেগুলো ঠিক করে দেয়।

**ব্যবহার:** একটি USB ড্রাইভে MacDoctor রাখুন → ক্যাবল/USB দিয়ে Mac-এ লাগান → বাকি কাজ MacDoctor করবে,
আর শেষে একটি রিপোর্ট দেবে (USB-তেই সেভ হবে)।

> ⚠️ **Mac চালুই হচ্ছে না / স্ক্রিনে সমস্যা / OCLP দিয়ে Sequoia বসানো ছিল?**
> সরাসরি এই গাইড দেখুন: **[docs/BOOT_FAILURE_GUIDE.md](docs/BOOT_FAILURE_GUIDE.md)**

---

## কী কী পরীক্ষা ও ঠিক করে

| # | বিষয় | স্বয়ংক্রিয়ভাবে ঠিক করে | শুধু `--full` মোডে (জিজ্ঞেস করে) | আপনাকে জানায় |
|---|---|---|---|---|
| 1 | সিস্টেম | — | — | মডেল, macOS ভার্সন, অনেক দিন রিস্টার্ট না হওয়া |
| 2 | ডিস্ক | পুরনো Time Machine snapshot মুছে জায়গা খালি | — | SSD নষ্ট হচ্ছে কিনা (SMART), ফাইল সিস্টেমের ত্রুটি |
| 3 | পরিষ্কার | পুরনো cache, লগ, temp, Xcode DerivedData | — | বড় Trash |
| 4 | গতি | অব্যবহৃত মেমোরি খালি | — | যে অ্যাপ CPU খেয়ে ফেলছে, swap, অতিরিক্ত গরম |
| 5 | ইন্টারনেট | DNS cache পরিষ্কার, নতুন IP, Wi-Fi রিস্টার্ট | নেটওয়ার্ক সেটিং রিসেট | DNS সমস্যা |
| 6 | স্টার্টআপ | — | অ্যাডওয়্যার/ভাঙা স্টার্টআপ আইটেম কোয়ারেন্টাইন | অ্যাডওয়্যার অ্যাপ, থার্ড-পার্টি kext |
| 7 | ক্র্যাশ | — | — | kernel panic (হঠাৎ রিস্টার্ট) ও বারবার ক্র্যাশ করা অ্যাপ |
| 8 | সার্ভিস | স্বয়ংক্রিয় সময়, Spotlight চালু | Spotlight রিইনডেক্স, "Open With" মেনু রিবিল্ড, ফন্ট cache, Finder/Dock রিস্টার্ট | যারা sleep আটকে রাখছে |
| 9 | নিরাপত্তা | — | Gatekeeper ও ফায়ারওয়াল চালু | SIP, FileVault |
| 10 | ব্যাটারি | — | — | সাইকেল কাউন্ট, ব্যাটারির অবস্থা, গরমে গতি কমা |
| 11 | আপডেট | — | সব macOS আপডেট ইনস্টল | বাকি আপডেট |

**নিরাপত্তার নিয়ম:** MacDoctor কখনো আপনার Documents, Desktop, Downloads, Photos বা Trash-এর ফাইল মোছে না।
যা সরায় (স্টার্টআপ আইটেম, নেটওয়ার্ক সেটিং) তা ব্যাকআপ/কোয়ারেন্টাইনে রাখে, পরে ফেরত আনা যায়।

---

## ধাপ ১ — USB ড্রাইভ তৈরি (একবারই)

1. যেকোনো USB ড্রাইভ নিন (exFAT বা APFS ফরম্যাট ভালো; ব্যাকআপ রাখতে চাইলে বড় ড্রাইভ)।
2. এই repo ডাউনলোড করুন: GitHub-এ **Code → Download ZIP**, তারপর আনজিপ করুন।
3. Terminal খুলে (যে কোনো Mac বা Linux কম্পিউটারে):
   ```bash
   cd ~/Downloads/MacDoctor-main
   bash prepare-usb.sh /Volumes/আপনার_USB_এর_নাম
   ```
   Mac-এ ড্রাইভের নাম বদলে **MACDOCTOR** রাখা হবে।

## ধাপ ২ — ব্যবহার

### ক) সাধারণ উপায়: লাগান আর ডাবল-ক্লিক করুন
1. USB ড্রাইভ MacBook-এ লাগান (2017 MacBook Pro-তে USB-C পোর্ট, তাই দরকার হলে USB-C অ্যাডাপ্টার/ক্যাবল)।
2. Finder-এ **MACDOCTOR** খুলে **`MacDoctor.command`**-এ ডাবল-ক্লিক করুন।
   - প্রথমবার "unidentified developer" দেখালে: ফাইলে **রাইট-ক্লিক → Open → Open**।
   - USB-তে ঢোকার অনুমতি চাইলে **OK** দিন।
3. Mac-এর লগইন পাসওয়ার্ড দিন (টাইপ করার সময় কিছু দেখা যায় না, এটা স্বাভাবিক)।
4. ৫–১৫ মিনিট অপেক্ষা করুন। শেষে স্ক্রিনে সারাংশ ও USB-এর `reports` ফোল্ডারে পূর্ণ রিপোর্ট পাবেন।

### খ) সম্পূর্ণ অটোমেটিক: শুধু ক্যাবল লাগালেই চলবে
নিরাপত্তার কারণে macOS কোনো USB থেকে নিজে নিজে প্রোগ্রাম চালায় না। তাই একবার এই সেটআপ করুন:
```bash
sudo /Volumes/MACDOCTOR/setup-autorun.sh
```
এরপর থেকে **শুধু MACDOCTOR ড্রাইভ লাগালেই** MacDoctor নিজে চলবে (অটো মোড), শেষে নোটিফিকেশন দেবে
এবং রিপোর্ট TextEdit-এ খুলে দেখাবে। একই ড্রাইভ ৩০ মিনিটের মধ্যে আবার লাগালে আবার চলবে না।

- নিরাপত্তা: সেটআপের সময় Mac আর এই USB-এর মধ্যে একটি গোপন token তৈরি হয় — অন্য কোনো USB দিয়ে এটা চালানো যায় না,
  আর চলে Mac-এ ইনস্টল করা কপি, USB-এর কোড নয়। অটো মোডে কখনো ঝুঁকিপূর্ণ কিছু করা হয় না।
- না চললে: **System Settings → Privacy & Security → Full Disk Access**-এ `/bin/bash` যোগ করুন।
- লগ: `/var/log/macdoctor-autorun.log`
- সরাতে: `sudo /Volumes/MACDOCTOR/setup-autorun.sh --uninstall`
- MacDoctor আপডেট করলে USB নতুন করে তৈরি করে আবার `setup-autorun.sh` চালান।

### গ) Mac চালুই হচ্ছে না? — Recovery Mode
1. Mac বন্ধ করে USB লাগান।
2. পাওয়ার চেপেই **⌘ Command + R** চেপে ধরুন (না হলে **⌥ Option + ⌘ + R**)।
3. মেনু বার → **Utilities → Terminal**, তারপর লিখুন:
   ```sh
   sh /Volumes/MACDOCTOR/recovery/recovery-repair.sh
   ```
4. মেনু থেকে বেছে নিন: ডিস্ক মেরামত (First Aid), জরুরি ফাইল USB-তে ব্যাকআপ, NVRAM রিসেট,
   স্টার্টআপ প্রোগ্রাম সরানো, macOS রিইনস্টলের নিয়ম, crash-এর কারণ বিশ্লেষণ (GPU/SSD/গরম/OCLP),
   Intel GPU দিয়ে চালু (15" মডেল), এবং বুট অবস্থা (Windows, OpenCore, NVRAM)।

SMC/NVRAM রিসেট, Safe Mode, Apple Diagnostics-এর কী-কম্বিনেশন: **[docs/KEY_COMBOS.md](docs/KEY_COMBOS.md)**

---

## অপশন (Terminal থেকে চালালে)

```bash
sudo ./macdoctor.sh                 # অটো: পরীক্ষা + নিরাপদ সমাধান (ডিফল্ট)
sudo ./macdoctor.sh --diagnose      # শুধু পরীক্ষা, কিছু বদলাবে না
sudo ./macdoctor.sh --full          # ঝুঁকিপূর্ণ সমাধানও, প্রতিটার আগে জিজ্ঞেস করবে
sudo ./macdoctor.sh --dry-run       # কী করা হতো শুধু দেখাবে
sudo ./macdoctor.sh --quick         # ধীর পরীক্ষা (ডিস্ক verify, আপডেট) বাদ
sudo ./macdoctor.sh --only disk,network   # নির্দিষ্ট মডিউল
```
মডিউলের নাম: `system disk cleanup performance network startup crashes services security battery updates`

## যা MacDoctor পারে না
- হার্ডওয়্যার সমস্যা (নষ্ট SSD, ফোলা ব্যাটারি, লজিক বোর্ড, কীবোর্ড) ঠিক করা — শুধু শনাক্ত করে জানায়।
- ভুলে যাওয়া পাসওয়ার্ড/Activation Lock ভাঙা।
- macOS Ventura (13)-এর চেয়ে নতুন macOS বসানো — MacBook Pro 2017-এ Apple আনুষ্ঠানিকভাবে Ventura পর্যন্ত দেয়।

## প্রজেক্টের গঠন
```
MacDoctor.command        ডাবল-ক্লিক লঞ্চার
macdoctor.sh             মূল প্রোগ্রাম
lib/common.sh            লগিং, safe_fix / risky_fix, রিপোর্ট
modules/NN_*.sh          প্রতিটি পরীক্ষা আলাদা মডিউলে
setup-autorun.sh         "লাগালেই চলবে" সেটআপ
tools/autorun-trigger.sh অটো-রানের launchd হেল্পার
recovery/recovery-repair.sh  Recovery Mode-এর মেনু
prepare-usb.sh           USB ড্রাইভ তৈরি
tests/mock-run.sh        macOS ছাড়া (Linux CI) নকল কমান্ড দিয়ে পরীক্ষা
```

## ডেভেলপমেন্ট
```bash
shellcheck -x macdoctor.sh lib/*.sh modules/*.sh setup-autorun.sh prepare-usb.sh tools/*.sh
shellcheck -s sh recovery/recovery-repair.sh
tests/mock-run.sh --dry-run
```
নতুন সমস্যা যোগ করতে `modules/`-এ `mod_<নাম>()` ফাংশনসহ ফাইল বানিয়ে `macdoctor.sh`-এর `ALL_MODULES`-এ নাম দিন।
macOS-এর bash 3.2-তে চলতে হবে (associative array, `mapfile` ব্যবহার করবেন না)।
