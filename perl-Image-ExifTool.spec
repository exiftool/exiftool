Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 10.22
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
various manufacturers such as Canon, Casio, FLIR, FujiFilm, GE, HP,
JVC/Victor, Kodak, Leaf, Minolta/Konica-Minolta, Nikon, Olympus/Epson,
Panasonic/Leica, Pentax/Asahi, Phase One, Reconyx, Ricoh, Samsung, Sanyo,
Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DSS   r     | JPEG  r/w   | ODT   r     | RIFF  r
  3G2   r/w   | DV    r     | K25   r     | OFR   r     | RSRC  r
  3GP   r/w   | DVB   r/w   | KDC   r     | OGG   r     | RTF   r
  A     r     | DYLIB r     | KEY   r     | OGV   r     | RW2   r/w
  AA    r     | EIP   r     | LA    r     | ORF   r/w   | RWL   r/w
  AAX   r/w   | EPS   r/w   | LFP   r     | OTF   r     | RWZ   r
  ACR   r     | EPUB  r     | LNK   r     | PAC   r     | RM    r
  AFM   r     | ERF   r/w   | M2TS  r     | PAGES r     | SEQ   r
  AI    r/w   | EXE   r     | M4A/V r/w   | PBM   r/w   | SO    r
  AIFF  r     | EXIF  r/w/c | MEF   r/w   | PCD   r     | SR2   r/w
  APE   r     | EXR   r     | MIE   r/w/c | PDB   r     | SRF   r
  ARW   r/w   | EXV   r/w/c | MIFF  r     | PDF   r/w   | SRW   r/w
  ASF   r     | F4A/V r/w   | MKA   r     | PEF   r/w   | SVG   r
  AVI   r     | FFF   r/w   | MKS   r     | PFA   r     | SWF   r
  AZW   r     | FLA   r     | MKV   r     | PFB   r     | THM   r/w
  BMP   r     | FLAC  r     | MNG   r/w   | PFM   r     | TIFF  r/w
  BPG   r     | FLV   r     | MOBI  r     | PGF   r     | TORRENT r
  BTF   r     | FPF   r     | MODD  r     | PGM   r/w   | TTC   r
  CHM   r     | FPX   r     | MOI   r     | PLIST r     | TTF   r
  COS   r     | GIF   r/w   | MOS   r/w   | PICT  r     | VCF   r
  CR2   r/w   | GZ    r     | MOV   r/w   | PMP   r     | VRD   r/w/c
  CRW   r/w   | HDP   r/w   | MP3   r     | PNG   r/w   | VSD   r
  CS1   r/w   | HDR   r     | MP4   r/w   | PPM   r/w   | WAV   r
  DCM   r     | HTML  r     | MPC   r     | PPT   r     | WDP   r/w
  DCP   r/w   | ICC   r/w/c | MPG   r     | PPTX  r     | WEBP  r
  DCR   r     | ICS   r     | MPO   r/w   | PS    r/w   | WEBM  r
  DFONT r     | IDML  r     | MQV   r/w   | PSB   r/w   | WMA   r
  DIVX  r     | IIQ   r/w   | MRW   r/w   | PSD   r/w   | WMV   r
  DJVU  r     | IND   r/w   | MXF   r     | PSP   r     | WV    r
  DLL   r     | INX   r     | NEF   r/w   | QTIF  r/w   | X3F   r/w
  DNG   r/w   | ISO   r     | NRW   r/w   | RA    r     | XCF   r
  DOC   r     | ITC   r     | NUMBERS r   | RAF   r/w   | XLS   r
  DOCX  r     | J2C   r     | O     r     | RAM   r     | XLSX  r
  DPX   r     | JNG   r/w   | ODP   r     | RAR   r     | XMP   r/w/c
  DR4   r/w/c | JP2   r/w   | ODS   r     | RAW   r/w   | ZIP   r

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
