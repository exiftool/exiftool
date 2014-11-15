Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 9.76
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
  3FR   r     | EIP   r     | LA    r     | ORF   r/w   | RTF   r
  3G2   r/w   | EPS   r/w   | LFP   r     | OTF   r     | RW2   r/w
  3GP   r/w   | EPUB  r     | LNK   r     | PAC   r     | RWL   r/w
  ACR   r     | ERF   r/w   | M2TS  r     | PAGES r     | RWZ   r
  AFM   r     | EXE   r     | M4A/V r/w   | PBM   r/w   | RM    r
  AI    r/w   | EXIF  r/w/c | MEF   r/w   | PCD   r     | SEQ   r
  AIFF  r     | EXR   r     | MIE   r/w/c | PDB   r     | SO    r
  APE   r     | EXV   r/w/c | MIFF  r     | PDF   r/w   | SR2   r/w
  ARW   r/w   | F4A/V r/w   | MKA   r     | PEF   r/w   | SRF   r
  ASF   r     | FFF   r/w   | MKS   r     | PFA   r     | SRW   r/w
  AVI   r     | FLA   r     | MKV   r     | PFB   r     | SVG   r
  AZW   r     | FLAC  r     | MNG   r/w   | PFM   r     | SWF   r
  BMP   r     | FLV   r     | MOBI  r     | PGF   r     | THM   r/w
  BTF   r     | FPF   r     | MODD  r     | PGM   r/w   | TIFF  r/w
  CHM   r     | FPX   r     | MOS   r/w   | PLIST r     | TORRENT r
  COS   r     | GIF   r/w   | MOV   r/w   | PICT  r     | TTC   r
  CR2   r/w   | GZ    r     | MP3   r     | PMP   r     | TTF   r
  CRW   r/w   | HDP   r/w   | MP4   r/w   | PNG   r/w   | VRD   r/w/c
  CS1   r/w   | HDR   r     | MPC   r     | PPM   r/w   | VSD   r
  DCM   r     | HTML  r     | MPG   r     | PPT   r     | WAV   r
  DCP   r/w   | ICC   r/w/c | MPO   r/w   | PPTX  r     | WDP   r/w
  DCR   r     | IDML  r     | MQV   r/w   | PS    r/w   | WEBP  r
  DFONT r     | IIQ   r/w   | MRW   r/w   | PSB   r/w   | WEBM  r
  DIVX  r     | IND   r/w   | MXF   r     | PSD   r/w   | WMA   r
  DJVU  r     | INX   r     | NEF   r/w   | PSP   r     | WMV   r
  DLL   r     | ITC   r     | NRW   r/w   | QTIF  r/w   | WV    r
  DNG   r/w   | J2C   r     | NUMBERS r   | RA    r     | X3F   r/w
  DOC   r     | JNG   r/w   | ODP   r     | RAF   r/w   | XCF   r
  DOCX  r     | JP2   r/w   | ODS   r     | RAM   r     | XLS   r
  DPX   r     | JPEG  r/w   | ODT   r     | RAR   r     | XLSX  r
  DV    r     | K25   r     | OFR   r     | RAW   r/w   | XMP   r/w/c
  DVB   r/w   | KDC   r     | OGG   r     | RIFF  r     | ZIP   r
  DYLIB r     | KEY   r     | OGV   r     | RSRC  r     |

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
