import '../data/contact_repository.dart' show kDailyRequestMax, kOpenRequestMax;

/// English text for the Indonesian text used in the code (see [tr]). Add a
/// line here when a new Indonesian text should have an English version.
final Map<String, String> kEnglish = {
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
  'Turunkan lowongan ini?': 'Take down this job post?',
  'Alasan (dikirim ke pemasang)': 'Reason (sent to the poster)',
  'Cari judul, perusahaan atau pemasang': 'Search title, company or poster',
  'Belum ada lowongan.': 'No job posts yet.',
  'Tampilkan lagi': 'Show again',
  'Belum ada riwayat.': 'No history yet.',
  'Hapus bio ini?': 'Delete this bio?',
  'Hapus bio': 'Delete bio',
  'Setujui, tolak, tangguhkan. Produk bisnis yang disetujui langsung tayang': 'Approve, reject, suspend. Products of approved businesses go live at once',
  'Lihat semua lowongan, turunkan atau tampilkan lagi':
      'See all job posts, take down or show again',
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
