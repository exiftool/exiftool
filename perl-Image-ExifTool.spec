Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 13.31
Release: 1
License: Artistic/GPL
Group: Development/Libraries/Perl
URL: https://exiftool.org/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl modules plus a full-featured
command-line application for reading and writing meta information in a wide
variety of files, including the maker note information of many digital
cameras by various manufacturers such as Canon, Casio, DJI, FLIR, FujiFilm,
GE, GoPro, HP, JVC/Victor, Kodak, Leaf, Minolta/Konica-Minolta, Nikon,
Nintendo, Olympus/Epson, Panasonic/Leica, Pentax/Asahi, Phase One, Reconyx,
Ricoh, Samsung, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  360   r/w   | DOCX  r     | ITC   r     | NUMBERS r   | RAM   r
  3FR   r     | DPX   r     | J2C   r     | NXD   r     | RAR   r
  3G2   r/w   | DR4   r/w/c | JNG   r/w   | O     r     | RAW   r/w
  3GP   r/w   | DSS   r     | JP2   r/w   | ODP   r     | RIFF  r
  7Z    r     | DV    r     | JPEG  r/w   | ODS   r     | RSRC  r
  A     r     | DVB   r/w   | JSON  r     | ODT   r     | RTF   r
  AA    r     | DVR-MS r    | JXL   r/w   | OFR   r     | RW2   r/w
  AAC   r     | DYLIB r     | K25   r     | OGG   r     | RWL   r/w
  AAE   r     | EIP   r     | KDC   r     | OGV   r     | RWZ   r
  AAX   r/w   | EPS   r/w   | KEY   r     | ONP   r     | RM    r
  ACR   r     | EPUB  r     | LA    r     | OPUS  r     | SEQ   r
  AFM   r     | ERF   r/w   | LFP   r     | ORF   r/w   | SKETCH r
  AI    r/w   | EXE   r     | LIF   r     | ORI   r/w   | SO    r
  AIFF  r     | EXIF  r/w/c | LNK   r     | OTF   r     | SR2   r/w
  APE   r     | EXR   r     | LRV   r/w   | PAC   r     | SRF   r
  ARQ   r/w   | EXV   r/w/c | M2TS  r     | PAGES r     | SRW   r/w
  ARW   r/w   | F4A/V r/w   | M4A/V r/w   | PBM   r/w   | SVG   r
  ASF   r     | FFF   r/w   | MACOS r     | PCAP  r     | SWF   r
  AVI   r     | FITS  r     | MAX   r     | PCAPNG r    | THM   r/w
  AVIF  r/w   | FLA   r     | MEF   r/w   | PCD   r     | TIFF  r/w
  AZW   r     | FLAC  r     | MIE   r/w/c | PCX   r     | TORRENT r
  BMP   r     | FLIF  r/w   | MIFF  r     | PDB   r     | TTC   r
  BPG   r     | FLV   r     | MKA   r     | PDF   r/w   | TTF   r
  BTF   r     | FPF   r     | MKS   r     | PEF   r/w   | TXT   r
  C2PA  r     | FPX   r     | MKV   r     | PFA   r     | VCF   r
  CHM   r     | GIF   r/w   | MNG   r/w   | PFB   r     | VNT   r
  COS   r     | GLV   r/w   | MOBI  r     | PFM   r     | VRD   r/w/c
  CR2   r/w   | GPR   r/w   | MODD  r     | PGF   r     | VSD   r
  CR3   r/w   | GZ    r     | MOI   r     | PGM   r/w   | WAV   r
  CRM   r/w   | HDP   r/w   | MOS   r/w   | PLIST r     | WDP   r/w
  CRW   r/w   | HDR   r     | MOV   r/w   | PICT  r     | WEBP  r/w
  CS1   r/w   | HEIC  r/w   | MP3   r     | PMP   r     | WEBM  r
  CSV   r     | HEIF  r/w   | MP4   r/w   | PNG   r/w   | WMA   r
  CUR   r     | HTML  r     | MPC   r     | PPM   r/w   | WMV   r
  CZI   r     | ICC   r/w/c | MPG   r     | PPT   r     | WPG   r
  DCM   r     | ICO   r     | MPO   r/w   | PPTX  r     | WTV   r
  DCP   r/w   | ICS   r     | MQV   r/w   | PS    r/w   | WV    r
  DCR   r     | IDML  r     | MRC   r     | PSB   r/w   | X3F   r/w
  DFONT r     | IIQ   r/w   | MRW   r/w   | PSD   r/w   | XCF   r
  DIVX  r     | IND   r/w   | MXF   r     | PSP   r     | XISF  r
  DJVU  r     | INSP  r/w   | NEF   r/w   | QTIF  r/w   | XLS   r
  DLL   r     | INSV  r     | NKA   r     | R3D   r     | XLSX  r
  DNG   r/w   | INX   r     | NKSC  r/w   | RA    r     | XMP   r/w/c
  DOC   r     | ISO   r     | NRW   r/w   | RAF   r/w   | ZIP   r

  Meta Information
  ----------------------+----------------------+---------------------
  EXIF           r/w/c  |  CIFF           r/w  |  Ricoh RMETA    r
  GPS            r/w/c  |  AFCP           r/w  |  Picture Info   r
  IPTC           r/w/c  |  Kodak Meta     r/w  |  Adobe APP14    r
  XMP            r/w/c  |  FotoStation    r/w  |  MPF            r
  MakerNotes     r/w/c  |  PhotoMechanic  r/w  |  Stim           r
  Photoshop IRB  r/w/c  |  JPEG 2000      r    |  DPX            r
  ICC Profile    r/w/c  |  DICOM          r    |  APE            r
  MIE            r/w/c  |  Flash          r    |  Vorbis         r
  JFIF           r/w/c  |  FlashPix       r    |  SPIFF          r
  Ducky APP12    r/w/c  |  QuickTime      r    |  DjVu           r
  PDF            r/w/c  |  Matroska       r    |  M2TS           r
  PNG            r/w/c  |  MXF            r    |  PE/COFF        r
  Canon VRD      r/w/c  |  PrintIM        r    |  AVCHD          r
  Nikon Capture  r/w/c  |  FLAC           r    |  ZIP            r
  GeoTIFF        r/w/c  |  ID3            r    |  (and more)

See html/index.html for more details about ExifTool features.

%prep
%setup -n Image-ExifTool-%{version}

%build
perl Makefile.PL INSTALLDIRS=vendor

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall DESTDIR=%{?buildroot:%{buildroot}}
find $RPM_BUILD_ROOT -name perllocal.pod | xargs rm

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc Changes html
%{_libdir}/perl5/*
/usr/share/*/*
%{_mandir}/*/*
%{_bindir}/*

%changelog
* Tue May 06 2014 - Norbert de Rooy <nsrderooy@gmail.com>
- Spec file fixed for Redhat 6
* Tue May 09 2006 - Niels Kristian Bech Jensen <nkbj@mail.tele.dk>
- Spec file fixed for Mandriva Linux 2006.
* Mon May 08 2006 - Volker Kuhlmann <VolkerKuhlmann@gmx.de>
- Spec file fixed for SUSE.
- Package available from: http://volker.dnsalias.net/soft/
* Sat Jun 19 2004 Kayvan Sylvan <kayvan@sylvan.com> - Image-ExifTool
- Initial build.
