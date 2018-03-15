Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 10.86
Release: 1
License: Artistic/GPL
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl modules plus a full-featured
application for reading and writing meta information in a wide variety of
files, including the maker note information of many digital cameras by
various manufacturers such as Canon, Casio, DJI, FLIR, FujiFilm, GE, GoPro,
HP, JVC/Victor, Kodak, Leaf, Minolta/Konica-Minolta, Nikon, Nintendo,
Olympus/Epson, Panasonic/Leica, Pentax/Asahi, Phase One, Reconyx, Ricoh,
Samsung, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DV    r     | JP2   r/w   | ODS   r     | RAW   r/w
  3G2   r/w   | DVB   r/w   | JPEG  r/w   | ODT   r     | RIFF  r
  3GP   r/w   | DYLIB r     | JSON  r     | OFR   r     | RSRC  r
  A     r     | EIP   r     | K25   r     | OGG   r     | RTF   r
  AA    r     | EPS   r/w   | KDC   r     | OGV   r     | RW2   r/w
  AAX   r/w   | EPUB  r     | KEY   r     | OPUS  r     | RWL   r/w
  ACR   r     | ERF   r/w   | LA    r     | ORF   r/w   | RWZ   r
  AFM   r     | EXE   r     | LFP   r     | OTF   r     | RM    r
  AI    r/w   | EXIF  r/w/c | LNK   r     | PAC   r     | SEQ   r
  AIFF  r     | EXR   r     | M2TS  r     | PAGES r     | SKETCH r
  APE   r     | EXV   r/w/c | M4A/V r/w   | PBM   r/w   | SO    r
  ARW   r/w   | F4A/V r/w   | MAX   r     | PCD   r     | SR2   r/w
  ASF   r     | FFF   r/w   | MEF   r/w   | PDB   r     | SRF   r
  AVI   r     | FLA   r     | MIE   r/w/c | PDF   r/w   | SRW   r/w
  AZW   r     | FLAC  r     | MIFF  r     | PEF   r/w   | SVG   r
  BMP   r     | FLIF  r/w   | MKA   r     | PFA   r     | SWF   r
  BPG   r     | FLV   r     | MKS   r     | PFB   r     | THM   r/w
  BTF   r     | FPF   r     | MKV   r     | PFM   r     | TIFF  r/w
  CHM   r     | FPX   r     | MNG   r/w   | PGF   r     | TORRENT r
  COS   r     | GIF   r/w   | MOBI  r     | PGM   r/w   | TTC   r
  CR2   r/w   | GPR   r/w   | MODD  r     | PLIST r     | TTF   r
  CR3   r/w   | GZ    r     | MOI   r     | PICT  r     | VCF   r
  CRW   r/w   | HDP   r/w   | MOS   r/w   | PMP   r     | VRD   r/w/c
  CS1   r/w   | HDR   r     | MOV   r/w   | PNG   r/w   | VSD   r
  DCM   r     | HEIC  r     | MP3   r     | PPM   r/w   | WAV   r
  DCP   r/w   | HEIF  r     | MP4   r/w   | PPT   r     | WDP   r/w
  DCR   r     | HTML  r     | MPC   r     | PPTX  r     | WEBP  r
  DFONT r     | ICC   r/w/c | MPG   r     | PS    r/w   | WEBM  r
  DIVX  r     | ICS   r     | MPO   r/w   | PSB   r/w   | WMA   r
  DJVU  r     | IDML  r     | MQV   r/w   | PSD   r/w   | WMV   r
  DLL   r     | IIQ   r/w   | MRW   r/w   | PSP   r     | WV    r
  DNG   r/w   | IND   r/w   | MXF   r     | QTIF  r/w   | X3F   r/w
  DOC   r     | INX   r     | NEF   r/w   | R3D   r     | XCF   r
  DOCX  r     | ISO   r     | NRW   r/w   | RA    r     | XLS   r
  DPX   r     | ITC   r     | NUMBERS r   | RAF   r/w   | XLSX  r
  DR4   r/w/c | J2C   r     | O     r     | RAM   r     | XMP   r/w/c
  DSS   r     | JNG   r/w   | ODP   r     | RAR   r     | ZIP   r

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
