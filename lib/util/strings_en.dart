import '../data/contact_repository.dart' show kDailyRequestMax, kOpenRequestMax;

/// English text for the Indonesian text used in the code (see [tr]). Add a
/// line here when a new Indonesian text should have an English version.
final Map<String, String> kEnglish = {
  'Foto terbaik: landscape 3:2 (1200 x 800 px).':
      'Best photo: landscape 3:2 (1200 x 800 px).',
  'JPG, PNG atau WebP, maksimal 2 MB.': 'JPG, PNG or WebP, 2 MB at most.',
  'Spam atau penipuan': 'Spam or scam',
  'Tidak pantas': 'Inappropriate',
  'Berpura-pura jadi orang lain': 'Fake or pretending to be someone',
  'Informasi salah': 'Wrong information',
  'Lainnya': 'Other',
  'Sembunyikan': 'Hide',
  'Pengumuman diubah.': 'Announcement updated.',
  'Ubah': 'Edit',
  'Menunggu kamu: {0}.': 'Waiting for you: {0}.',
  'Penjual: {0}': 'Seller: {0}',
  'Disembunyikan: {0}': 'Hidden: {0}',
  'Ditangguhkan: {0}': 'Suspended: {0}',
  // Texts with values (trf)
  'Selamat datang kembali, {0}': 'Welcome back, {0}',
  '"{0}" akan dihapus permanen untuk semua orang.':
      '"{0}" will be deleted permanently for everyone.',
  'Tampil di Home: {0} produk, {1} lowongan. Yang dipin tampil dulu, urutan 1 paling depan.': 'Shown on Home: {0} products, {1} jobs. Pinned ones come first, number 1 at the front.',
  'Blokir {0} dibuka.': '{0} unblocked.',
  'Tidak bisa dibuka. Salin {0} saja.': 'Could not open. Just copy {0}.',
  'Tersalin: {0}': 'Copied: {0}',
  '{0} alumni ingin terhubung denganmu. Lihat permintaan':
      '{0} alumni want to connect with you. See requests',
  '"{0}" dan semua produknya akan dihapus permanen.':
      '"{0}" and all its products will be deleted permanently.',
  'Minta kontak ke {0}': 'Request contact from {0}',
  'Permintaan terkirim ke {0}.': 'Request sent to {0}.',
  'Permintaan ke {0} akan ditarik.': 'Your request to {0} will be withdrawn.',
  'Diterima. {0} sekarang bisa melihat kontak yang kamu bagikan.':
      'Accepted. {0} can now see the contact you shared.',
  'Foto {0}': 'Photo of {0}',
  '{0} diblokir.': '{0} blocked.',
  'Blokir {0}?': 'Block {0}?',
  // Screen sweep (5 Nov)
  'Lanjut': 'Continue',
  'Verifikasi emailmu untuk melanjutkan.': 'Verify your email to continue.',
  'Bukan kamu? Ganti akun': 'Not you? Switch account',
  'Lupa PIN? Verifikasi ulang': 'Forgot PIN? Verify again',
  'Masukkan PIN kamu saat ini': 'Enter your current PIN',
  'Hapus PIN': 'Delete PIN',
  'Ubah PIN': 'Change PIN',
  'Atur PIN': 'Set PIN',
  'Lingkaran akan terbuka di ponsel ini tanpa PIN. Kamu bisa membuat PIN baru kapan saja.': 'Lingkaran will open on this phone without a PIN. You can create a new PIN any time.',
  'Hapus PIN?': 'Delete PIN?',
  'Nanti saja': 'Not now',
  'Aktifkan': 'Turn on',
  'Kembali dan keluar': 'Go back and exit',
  'Saya Setuju': 'I Agree',
  'Saya sudah membaca dan menyetujui Syarat dan Ketentuan Aplikasi':
      'I have read and agree to the App Terms and Conditions',
  'Gulir sampai bawah untuk melanjutkan.': 'Scroll to the bottom to continue.',
  'Syarat dan Ketentuan Aplikasi': 'App Terms and Conditions',
  'Lepas': 'Unpin',
  'Turunkan': 'Move down',
  'Tangguhkan': 'Suspend',
  'Lowongan ditangguhkan. Pemasang diberi tahu.': 'Job suspended. The poster was notified.',
  'Lowongan ditampilkan lagi.': 'Job shown again.',
  'Naikkan': 'Move up',
  'Home sudah penuh. Lepas satu pin dulu.': 'Home is full. Unpin one first.',
  'Belum ada yang dipin. Home menampilkan yang terbaru.':
      'Nothing is pinned yet. Home shows the newest.',
  'Dipin': 'Pinned',
  'Jenis': 'Type',
  'Kontak hilang dari Kontak Ikafe. Pilih Sembunyikan kalau mau menyimpannya.': 'The contact will disappear from Kontak Ikafe. Choose Hide if you want to keep it.',
  'Hanya bio yang dihapus. Akun tidak ikut dihapus dan orangnya masih bisa menulis bio baru.': 'Only the bio is removed. The account is not deleted and the person can still write a new bio.',
  'Riwayat': 'History',
  'Kamu belum memblokir siapa pun.': 'You have not blocked anyone.',
  'Kategori': 'Category',
  'Contoh: WA: 08xxx, Shopee: Toko Natasya, Ig: Toko Natasya. Kosongkan untuk memakai emailmu.': 'Example: WA: 08xxx, Shopee: Toko Natasya, Ig: Toko Natasya. Leave empty to use your email.',
  'Kontak atau nama Online Shop yang akan dibagikan':
      'Contact or Online Shop name to share',
  'Terisi otomatis saat kamu menerima permintaan kontak. Kamu tetap bisa mengubahnya setiap kali, dan tidak ada yang dibagikan sebelum kamu menekan Terima.': 'Filled in automatically when you accept a contact request. You can still change it every time, and nothing is shared before you press Accept.',
  'Buka': 'Open',
  'Kontak hanya dibagikan saat kamu menerima permintaan kontak, dan kamu tetap mengonfirmasinya setiap kali.': 'Contact is only shared when you accept a contact request, and you confirm it every time.',
  'Lengkapi profilmu agar sesama alumni lebih mudah mengenalimu. Langkah ini opsional dan bisa kamu lewati. Semuanya bisa diubah kapan saja di Profile.': 'Complete your profile so fellow alumni can recognise you more easily. This step is optional and you can skip it. Everything can be changed any time in Profile.',
  'Bantuan': 'Help',
  'Daftarkan': 'Register',
  'Memiliki usaha? Biar sesama alumni bisa menemukannya.':
      'Own a business? Let fellow alumni find it.',
  'Dukung Usaha Alumni': 'Support Alumni Businesses',
  'Lihat semua pengumuman': 'See all announcements',
  'Lowongan baru': 'New jobs',
  'Lengkapi profilmu: tambahkan kota dan pekerjaan agar alumni lain bisa menemukanmu.': 'Complete your profile: add your city and job so other alumni can find you.',
  'Lamaranmu untuk lowongan ini akan dihapus. Kamu bisa melamar lagi nanti.': 'Your application for this job will be removed. You can apply again later.',
  'Contoh data. Kontak resmi Ikafe menyusul.':
      'Sample data. Official Ikafe contacts are coming.',
  'Harga boleh dikosongkan kalau bisa nego.':
      'The price can be left empty if it is negotiable.',
  'Hapus lowongan': 'Delete job',
  'Lowongan diperbarui.': 'Job updated.',
  'Kamu belum punya produk. Gunakan "Tambah produk" di Marketplace untuk memasangnya.':
      'You have no products yet. Use "Add product" in Marketplace to post one.',
  'Semua notifikasimu akan dihapus permanen.':
      'All your notifications will be deleted permanently.',
  'Geser dan cubit (atau scroll) untuk mengatur posisi foto. Perkecil agar foto tampak utuh dengan latar putih. Bagian di dalam bingkai yang akan tersimpan.': 'Drag and pinch (or scroll) to set the photo position. Zoom out to show the whole photo on a white background. The part inside the frame is what gets saved.',
  'Foto tidak bisa disimpan. Coba lagi.':
      'The photo could not be saved. Try again.',
  'Perhatian: Dilarang menulis kata kasar, SARA, ujaran kebencian, konten dewasa, atau data pribadi orang lain. Bio yang dilaporkan bisa dihapus admin.': 'Note: Do not write rude words, ethnic or religious hate, hate speech, adult content, or other people\'s personal data. Reported bios can be removed by an admin.',
  'Akun': 'Account',
  'Sedang menunggu jawaban. Kamu akan dapat notifikasi saat ada jawaban.':
      'Waiting for an answer. You will get a notification when there is one.',
  'Boleh dikosongkan. Tautan ini tampil di profilmu untuk alumni lain.':
      'Can be left empty. This link shows on your profile for other alumni.',
  'Pratinjau foto profil': 'Profile photo preview',
  'Dia akan melihat namamu dan pesanmu. Kalau dia setuju, dia sendiri yang memilih kontak apa yang dibagikan ke kamu. Jawabannya muncul di Permintaan dan di Notifikasi.': 'They will see your name and your message. If they agree, they choose which contact to share with you. The answer appears in Requests and in Notifications.',
  'Kontak bawaanmu sudah terisi (atau emailmu bila belum diatur). Ubah sesukamu: WhatsApp, Instagram, telepon, email, atau nama online shop. Hanya orang ini yang bisa melihatnya. Atur kontak bawaan di Profile > Pengaturan.': 'Your default contact is already filled in (or your email if not set). Change it any way you like: WhatsApp, Instagram, phone, email, or an online shop name. Only this person can see it. Set your default contact in Profile > Settings.',
  'Kontak belum bisa dimuat. Coba lagi nanti.':
      'Contacts could not be loaded. Try again later.',
  'Belum ada kontak. Kontak yang dibagikan alumni lain setelah menerima permintaanmu akan tersimpan di sini.': 'No contacts yet. Contacts that other alumni share after accepting your request are saved here.',
  'Terjadi Kesalahan': 'Something went wrong',
  'Kembali': 'Back',
  'Akun ditangguhkan': 'Account suspended',
  'Kode tidak masuk atau email berubah?':
      'Code did not arrive or email changed?',
  'Belum masuk? Cek folder spam atau junk. Kode berlaku untuk waktu terbatas.': 'Not arrived? Check your spam or junk folder. The code is valid for a limited time.',
  'Beta tertutup. Tampilan sementara, bukan identitas resmi UNDIP atau Ikafe.':
      'Closed beta. Temporary look, not an official UNDIP or Ikafe identity.',
  'Beta tertutup · data awal dari anggota Ikafe':
      'Closed beta · starting data from Ikafe members',
  'Verifikasi dirimu, cari alumni berdasarkan jurusan dan angkatan, dukung usaha alumni, dan rekomendasikan lowongan kerja.': 'Verify yourself, find alumni by major and year, support alumni businesses, and recommend jobs.',
  'Jejaring alumni FEB Undip untuk saling terhubung, berbagi peluang, dan tumbuh bersama': 'The FEB Undip alumni network to connect, share opportunities, and grow together',
  'This is a closed test. Please use test contact details. Do not upload a real CV or enter a real phone number yet. (Ini uji coba tertutup. Gunakan data kontak percobaan, jangan unggah CV asli atau isi nomor telepon asli.)': 'This is a closed test. Please use test contact details. Do not upload a real CV or enter a real phone number yet.',
  'Laporkan': 'Report',
  'Blokir': 'Block',
  'Kamu tidak akan melihat profil, lowongan, produk atau usahanya, dan dia tidak bisa mengirim permintaan kontak kepadamu. Dia tidak diberi tahu. Kamu bisa membuka blokirnya lagi di Profile > Pengguna terblokir.': 'You will not see their profile, jobs, products or business, and they cannot send you contact requests. They are not told. You can unblock them in Profile > Blocked users.',
  'Foto terbaik: persegi 1:1 (800 x 800 px), wajah di tengah. JPG, PNG atau WebP, maksimal 2 MB. Foto dipotong bulat di layar.': 'Best photo: square 1:1 (800 x 800 px), face in the centre. JPG, PNG or WebP, 2 MB at most. The photo is cropped round on screen.',
  'Admin akan memeriksanya. Orangnya tidak diberi tahu siapa yang melapor.':
      'An admin will look into it. The person is not told who reported.',
  'Lowongan ini sudah ditutup.': 'This job is closed.',
  'Mulai': 'Start',
  'Lewati': 'Skip',
  'Kota': 'City',
  // Settings and language
  'Pengaturan': 'Settings',
  'Bahasa': 'Language',
  'Pilih bahasa': 'Choose language',
  'Default kontak untuk dibagikan': 'Default contact to share',
  'Terisi ketika menerima request': 'Filled in when you accept a request',
  'Pengenalan fitur': 'Feature introduction',
  'Apa itu Marketplace, Business, dan Jobs':
      'What Marketplace, Business and Jobs are',
  'Blokir pengguna': 'Blocked users',
  'Pengguna terblokir, buka blokir': 'See blocked users, unblock them',
  'Zona bahaya': 'Danger zone',
  'Hapus akun saya': 'Delete my account',
  // Generic
  'Batal': 'Cancel',
  'Simpan': 'Save',
  'Hapus': 'Delete',
  'Urungkan': 'Undo',
  'Dibatalkan.': 'Undone.',
  'Salin': 'Copy',
  'Tutup': 'Close',
  // Errors
  'Terjadi kesalahan. Coba lagi.': 'Something went wrong. Please try again.',
  'Tidak bisa terhubung ke server. Periksa koneksimu lalu coba lagi.':
      "Couldn't reach the server. Check your connection and try again.",
  // Requests
  'Diterima': 'Received',
  'Terkirim': 'Sent',
  'Kontak': 'Contacts',
  'Menunggu persetujuan': 'Waiting for approval',
  'Batalkan': 'Cancel request',
  'Tolak': 'Decline',
  'Terima': 'Accept',
  'Menunggu jawaban': 'Waiting for an answer',
  'Belum diterima': 'Not accepted',
  'Dibatalkan': 'Cancelled',
  'Lihat daftar kontak': 'Show contact',
  'Tanpa pesan.': 'No message.',
  'Kamu sudah menerima permintaan ini.': 'You accepted this request.',
  'Kamu sudah menolak permintaan ini.': 'You declined this request.',
  'Permintaan ditolak.': 'Request declined.',
  'Orang ini menolak permintaanmu dalam 30 hari terakhir. Kamu bisa mengirim lagi setelah 30 hari.': 'This person declined your request in the last 30 days. You can send another after 30 days.',
  'Kamu belum bisa mengirim permintaan ke orang ini.':
      'You cannot send a request to this person yet.',
  // Business and approval
  'Permintaanmu sudah kami terima dan sedang diproses admin. Kamu akan mendapat pemberitahuan di Notifikasi begitu ada keputusan.': 'We received your request and an admin is processing it. You will get a notification as soon as there is a decision.',
  'Permintaanmu sudah kami terima dan sedang diproses admin. Kamu akan mendapat pemberitahuan begitu ada keputusan.': 'We received your request and an admin is processing it. You will get a notification as soon as there is a decision.',
  'Hapus bisnis ini?': 'Delete this business?',
  'Bisnis dihapus.': 'Business deleted.',
  'Hapus lowongan ini?': 'Delete this job post?',
  'Lowongan dihapus.': 'Job post deleted.',
  'Ubah lowongan': 'Edit job post',
  'Tutup lowongan': 'Close job post',
  'Buka lagi': 'Reopen',
  'Hapus semua': 'Delete all',
  'Hapus semua notifikasi?': 'Delete all notifications?',
  // Marketplace
  'Harga bisa nego': 'Price is negotiable',
  'Harga nego': 'Negotiable',
  'Hubungi penjual': 'Contact the seller',
  'Kota (opsional)': 'City (optional)',
  'Hapus kota': 'Remove city',
  'Atur foto': 'Adjust photo',
  'Tarik lamaran': 'Withdraw application',
  // Contact request messages
  'Hanya alumni terverifikasi yang bisa memakai fitur ini.':
      'Only verified alumni can use this feature.',
  'Kamu tidak bisa mengirim permintaan ke dirimu sendiri.':
      'You cannot send a request to yourself.',
  'Kamu sudah punya permintaan yang belum dijawab ke orang ini. '
          'Tunggu jawabannya dulu.':
      'You already have an unanswered request to this person. Wait for the '
      'answer first.',
  'Kamu sudah mengirim $kDailyRequestMax permintaan hari ini. '
          'Coba lagi besok.':
      'You already sent $kDailyRequestMax requests today. Try again tomorrow.',
  'Ada $kOpenRequestMax permintaanmu yang belum dijawab. Kamu '
          'bisa mengirim lagi setelah ada yang dijawab, atau batalkan '
          'salah satunya.':
      'You have $kOpenRequestMax unanswered requests. You can send more once '
      'one is answered, or cancel one.',
  'Orang ini sudah membagikan kontaknya ke kamu. Lihat di '
          'Requests.':
      'This person already shared their contact with you. See it in Requests.',
  'Pesannya terlalu panjang (maksimal 200 karakter).':
      'The message is too long (200 characters at most).',
  'Isi kontak yang ingin kamu bagikan.': 'Enter the contact you want to share.',
  'Terlalu panjang (maksimal 200 karakter).':
      'Too long (200 characters at most).',
  'Permintaan ini sudah tidak ada.': 'This request no longer exists.',
  'Permintaan ini bukan milikmu.': 'This request is not yours.',
  'Permintaan ini belum diterima.': 'This request is not accepted yet.',
  'Permintaan ini sudah dijawab.': 'This request was already answered.',
  // Sign-in
  'Terlalu banyak permintaan kode. Tunggu beberapa menit, lalu coba lagi.':
      'Too many code requests. Wait a few minutes, then try again.',
  'Terlalu banyak kode yang salah. Minta kode baru untuk lanjut.':
      'Too many wrong codes. Request a new code to continue.',
  'Kamu sudah memasang terlalu banyak lowongan. Maksimal 5 per hari dan '
          '20 lowongan aktif. Tutup atau hapus yang lama dulu.':
      'You posted too many jobs. Maximum 5 per day and 20 active jobs. Close '
      'or delete older ones first.',
  // Screens (batch 1)
  'Pengumuman dihapus.': 'Announcement deleted.',
  'Pengumuman diposting.': 'Announcement posted.',
  'Status feedback diubah.': 'Feedback status changed.',
  'Urutan Home disimpan.': 'Home order saved.',
  'Riwayat admin': 'Admin history',
  'Tarik lamaran?': 'Withdraw application?',
  'Abaikan laporan': 'Dismiss reports',
  'Ceritakan singkat tentang dirimu': 'Tell us a little about yourself',
  'Permintaan terkirim': 'Request sent',
  'LinkedIn (opsional)': 'LinkedIn (optional)',
  'Verifikasi Status Alumni': 'Verify alumni status',
  'Menu lainnya': 'More options',
  'Hapus pengumuman ini?': 'Delete this announcement?',
  'Belum dipin': 'Not pinned yet',
  'Kontak Ikafe': 'Ikafe contacts',
  'Tambah kontak': 'Add contact',
  'Belum ada kontak.': 'No contacts yet.',
  'Hapus kontak ini?': 'Delete this contact?',
  'Nama kontak': 'Contact name',
  'Nomor, email, @akun atau link': 'Number, email, @account or link',
  'Urutan (angka kecil tampil lebih dulu)': 'Order (small numbers show first)',
  'Tampil di Kontak Ikafe': 'Shown in Ikafe contacts',
  'Tangguhkan lowongan ini?': 'Suspend this job post?',
  'Alasan (dikirim ke pemasang)': 'Reason (sent to the poster)',
  'Cari judul, perusahaan atau pemasang': 'Search title, company or poster',
  'Belum ada lowongan.': 'No job posts yet.',
  'Tampilkan lagi': 'Show again',
  'Belum ada riwayat.': 'No history yet.',
  'Hapus bio ini?': 'Delete this bio?',
  'Hapus bio': 'Delete bio',
  'Setujui, tolak, tangguhkan. Produk bisnis yang disetujui langsung tayang': 'Approve, reject, suspend. Products of approved businesses go live at once',
  'Lihat semua lowongan, tangguhkan atau tampilkan lagi':
      'See all job posts, suspend or show again',
  'Siapa menyetujui, menolak, menyembunyikan atau menghapus apa':
      'Who approved, rejected, hid or deleted what',
  'Pilih produk dan lowongan yang tampil dulu di Home':
      'Choose which products and jobs show first on Home',
  'Pengguna terblokir': 'Blocked users',
  'Buka blokir': 'Unblock',
  'Kontak admin': 'Contact admin',
  'Buka LinkedIn member ini?': 'Open this member\'s LinkedIn?',
  'Cari nama atau perusahaan...': 'Search name or company...',
  'Tidak ada alumni yang cocok.': 'No alumni match.',
  'Hapus filter': 'Clear filters',
  'Buka LinkedIn': 'Open LinkedIn',
  'Pilih foto': 'Choose photo',
  'Kontak yang mau dibagikan': 'Contact to share',
  'Belum ada lowongan. Lowongan baru akan muncul di sini.':
      'No job posts yet. New ones will show up here.',
  'Cari alumni': 'Find alumni',
  'Lihat semua': 'See all',
  'Belum ada produk. Produk yang disetujui akan muncul di sini.':
      'No products yet. Approved products will show up here.',
  'Kontak belum bisa dimuat.': 'Contacts could not be loaded.',
  'Sembunyikan produk ini?': 'Hide this product?',
  'Alasan (dikirim ke pemilik)': 'Reason (sent to the owner)',
  'Tampilkan yang diabaikan': 'Show dismissed',
  'Sembunyikan produk': 'Hide product',
  'Tambah produk ke usaha yang mana?': 'Add the product to which business?',
  'Produk saya': 'My products',
  'Tambah produk': 'Add product',
  'Ubah foto profil': 'Change profile photo',
  'Minta kontak': 'Request contact',
  'Kontak, PIN, pengguna terblokir, hapus akun':
      'Contact, PIN, blocked users, delete account',
  'Kontak admin, beri masukan, tentang aplikasi':
      'Contact admin, send feedback, about the app',
  'Kebijakan Privasi dan Ketentuan': 'Privacy Policy and Terms',
  'Foto profil': 'Profile photo',
  'Hapus foto': 'Remove photo',
  'Pesan (disarankan)': 'Message (recommended)',
  'Contoh: kenapa kamu ingin terhubung': 'Example: why you want to connect',
  'Kirim permintaan': 'Send request',
  'Kontak apa yang ingin kamu bagikan?': 'What contact do you want to share?',
  'Kontak atau nama Online Shop yang akan dibagikan *':
      'Contact or Online Shop name to share *',
  'Terima dan bagikan': 'Accept and share',
  'Batalkan permintaan?': 'Cancel the request?',
  'Kode baru sudah dikirim': 'A new code was sent',
  'Kode 6 digit': '6-digit code',
  'Pakai email lain': 'Use another email',
  'Belum terdaftar? Hubungi tim admin':
      'Not registered? Contact the admin team',
  'Hubungi tim admin': 'Contact the admin team',
  'Coba lagi': 'Try again',
  'Kirim masukan': 'Send feedback',
  'Lihat detail': 'See details',
  'Tidak bisa memblokir. Coba lagi.': 'Could not block. Try again.',
  'Blokir alumni ini': 'Block this alum',
  'Catatan (opsional)': 'Note (optional)',
  'Kirim Laporan': 'Send report',
};
