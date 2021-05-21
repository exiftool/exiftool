Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 12.26
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
  360   r/w   | DPX   r     | ITC   r     | NUMBERS r   | RAM   r
  3FR   r     | DR4   r/w/c | J2C   r     | O     r     | RAR   r
  3G2   r/w   | DSS   r     | JNG   r/w   | ODP   r     | RAW   r/w
  3GP   r/w   | DV    r     | JP2   r/w   | ODS   r     | RIFF  r
  A     r     | DVB   r/w   | JPEG  r/w   | ODT   r     | RSRC  r
  AA    r     | DVR-MS r    | JSON  r     | OFR   r     | RTF   r
  AAE   r     | DYLIB r     | JXL   r     | OGG   r     | RW2   r/w
  AAX   r/w   | EIP   r     | K25   r     | OGV   r     | RWL   r/w
  ACR   r     | EPS   r/w   | KDC   r     | ONP   r     | RWZ   r
  AFM   r     | EPUB  r     | KEY   r     | OPUS  r     | RM    r
  AI    r/w   | ERF   r/w   | LA    r     | ORF   r/w   | SEQ   r
  AIFF  r     | EXE   r     | LFP   r     | ORI   r/w   | SKETCH r
  APE   r     | EXIF  r/w/c | LNK   r     | OTF   r     | SO    r
  ARQ   r/w   | EXR   r     | LRV   r/w   | PAC   r     | SR2   r/w
  ARW   r/w   | EXV   r/w/c | M2TS  r     | PAGES r     | SRF   r
  ASF   r     | F4A/V r/w   | M4A/V r/w   | PBM   r/w   | SRW   r/w
  AVI   r     | FFF   r/w   | MACOS r     | PCD   r     | SVG   r
  AVIF  r/w   | FITS  r     | MAX   r     | PCX   r     | SWF   r
  AZW   r     | FLA   r     | MEF   r/w   | PDB   r     | THM   r/w
  BMP   r     | FLAC  r     | MIE   r/w/c | PDF   r/w   | TIFF  r/w
  BPG   r     | FLIF  r/w   | MIFF  r     | PEF   r/w   | TORRENT r
  BTF   r     | FLV   r     | MKA   r     | PFA   r     | TTC   r
  CHM   r     | FPF   r     | MKS   r     | PFB   r     | TTF   r
  COS   r     | FPX   r     | MKV   r     | PFM   r     | TXT   r
  CR2   r/w   | GIF   r/w   | MNG   r/w   | PGF   r     | VCF   r
  CR3   r/w   | GPR   r/w   | MOBI  r     | PGM   r/w   | VRD   r/w/c
  CRM   r/w   | GZ    r     | MODD  r     | PLIST r     | VSD   r
  CRW   r/w   | HDP   r/w   | MOI   r     | PICT  r     | WAV   r
  CS1   r/w   | HDR   r     | MOS   r/w   | PMP   r     | WDP   r/w
  CSV   r     | HEIC  r/w   | MOV   r/w   | PNG   r/w   | WEBP  r
  CZI   r     | HEIF  r/w   | MP3   r     | PPM   r/w   | WEBM  r
  DCM   r     | HTML  r     | MP4   r/w   | PPT   r     | WMA   r
  DCP   r/w   | ICC   r/w/c | MPC   r     | PPTX  r     | WMV   r
  DCR   r     | ICS   r     | MPG   r     | PS    r/w   | WTV   r
  DFONT r     | IDML  r     | MPO   r/w   | PSB   r/w   | WV    r
  DIVX  r     | IIQ   r/w   | MQV   r/w   | PSD   r/w   | X3F   r/w
  DJVU  r     | IND   r/w   | MRC   r     | PSP   r     | XCF   r
  DLL   r     | INSP  r/w   | MRW   r/w   | QTIF  r/w   | XLS   r
  DNG   r/w   | INSV  r     | MXF   r     | R3D   r     | XLSX  r
  DOC   r     | INX   r     | NEF   r/w   | RA    r     | XMP   r/w/c
  DOCX  r     | ISO   r     | NRW   r/w   | RAF   r/w   | ZIP   r

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
