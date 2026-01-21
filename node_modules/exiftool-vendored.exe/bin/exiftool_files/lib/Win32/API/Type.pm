package Win32::API::Type;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

#######################################################################
#
# Win32::API::Type - Perl Win32 API type definitions
#
# Author: Aldo Calpini <dada@perl.it>
# Maintainer: Cosimo Streppone <cosimo@cpan.org>
#
#######################################################################

use strict;
use warnings;
use vars qw( %Known %PackSize %Modifier %Pointer $VERSION );

$VERSION = '0.70';

#import DEBUG sub
sub DEBUG;
*DEBUG = *Win32::API::DEBUG;

#const optimize
BEGIN {
    eval ' sub pointer_pack_type () { \''
    .(PTRSIZE == 8 ? 'Q' : 'L').
    '\' }';
}

%Known    = ();
%PackSize = ();
%Modifier = ();
%Pointer  = ();

# Initialize data structures at startup.
# Aldo wants to keep the <DATA> approach.
#
my $section = 'nothing';
foreach (<DATA>) {
    next if /^\s*(?:#|$)/;
    chomp;
    if (/\[(.+)\]/) {
        $section = $1;
        next;
    }
    if ($section eq 'TYPE') {
        my ($name, $packing) = split(/\s+/);

        # DEBUG "(PM)Type::INIT: Known('$name') => '$packing'\n";
        $packing = pointer_pack_type()
            if ($packing eq '_P');
        $Known{$name} = $packing;
    }
    elsif ($section eq 'POINTER') {
        my ($pointer, $pointto) = split(/\s+/);

        # DEBUG "(PM)Type::INIT: Pointer('$pointer') => '$pointto'\n";
        $Pointer{$pointer} = $pointto;
    }
    elsif ($section eq 'PACKSIZE') {
        my ($packing, $size) = split(/\s+/);

        # DEBUG "(PM)Type::INIT: PackSize('$packing') => '$size'\n";
        $size = PTRSIZE
            if ($size eq '_P');
        $PackSize{$packing} = $size;
    }
    elsif ($section eq 'MODIFIER') {
        my ($modifier, $mapto) = split(/\s+/, $_, 2);
        my %maps = ();
        foreach my $item (split(/\s+/, $mapto)) {
            my ($k, $v) = split(/=/, $item);
            $maps{$k} = $v;
        }

        # DEBUG "(PM)Type::INIT: Modifier('$modifier') => '%maps'\n";
        $Modifier{$modifier} = {%maps};
    }
}
close(DATA);

sub new {
    my $class   = shift;
    my ($type)  = @_;
    my $packing = packing($type);
    my $size    = sizeof($type);
    my $self    = {
        type    => $type,
        packing => $packing,
        size    => $size,
    };
    return bless $self;
}

sub typedef {
    my $class = shift;
    my ($name, $type) = @_;
    $type =~ m/^\s*(.*?)\s*$/;
    $type =~ m/^(.+?)\s*(\*)$/;
    $type = $1;
    $type .= $2 if defined $2;
    $name =~ m/^\s*(.*?)\s*$/;
    $name =~ m/^(.+?)\s*(\*)$/;
    $name = $1;
    $name .= $2 if defined $2;
    #FIXME BUG, unsigned __int64 * doesn't pase in typedef, it does in parse_prototype
    my $packing = packing($type, $name); #FIXME BUG
    if(! defined $packing){
        warn "Win32::API::Type::typedef: WARNING unknown type '$_[1]'";
        return undef;
    }
    #Win32::API::Struct logic
    #limitation, this won't alias a new struct type to an existing struct type
    #this only creates new struct type pointer types to an existing struct type
    if($packing eq '>'){
        if(is_pointer($type)){
        $packing = 'T';
        $type =~ s/\s*\*$//; #chop off '   *'
        $Win32::API::Struct::Pointer{$name} = $type;
        }
        else{
        warn "Win32::API::Type::typedef: aliasing struct \"".$_[0]
        ."\" to struct \"".$_[1]."\" not supported";
        return undef;            
        }
    }
    DEBUG "(PM)Type::typedef: packing='$packing'\n" if DEBUGCONST;
    if($packing eq 'p'){
        $Pointer{$name} = $Pointer{$type};
    }else{
        $Known{$name} = $packing;
    }
    return 1;
}


sub is_known {
    my $self = shift;
    my $type = shift;
    $type = $self unless defined $type;
    if (ref($type) =~ /Win32::API::Type/) {
        return 1;
    }
    else {
        return defined packing($type);
    }
}

sub sizeof {
    my $self = shift;
    my $type = shift;
    $type = $self unless defined $type;
    if (ref($type) =~ /Win32::API::Type/) {
        return $self->{size};
    }
    else {
        my $packing = packing($type);
        if ($packing =~ /(\w)\*(\d+)/) {
            return $PackSize{$1} * $2;
        }
        else {
            return $PackSize{$packing};
        }
    }
}
# $packing_letter = packing( [$class = 'Win32::API::Type' ,] $type [, $pass_numeric])
sub packing {

    # DEBUG "(PM)Type::packing: called by ". join("::", (caller(1))[0,3]). "\n";
    my $self       = shift;
    my $is_pointer = 0;
    if (ref($self) =~ /Win32::API::Type/) {

        # DEBUG "(PM)Type::packing: got an object\n";
        return $self->{packing};
    }
    my $type = ($self eq 'Win32::API::Type') ? shift : $self;
    my $name = shift;
    my $pass_numeric = shift;
    
    # DEBUG "(PM)Type::packing: got '$type', '$name'\n";
    my ($modifier, $size, $packing);
    if (exists $Pointer{$type}) {

        # DEBUG "(PM)Type::packing: got '$type', is really '$Pointer{$type}'\n";
        $type       = $Pointer{$type};
        $is_pointer = 1;
    }
    elsif ($type =~ /(\w+)\s+(\w+)/) {
        $modifier = $1;
        $type     = $2;

        # DEBUG "(PM)packing: got modifier '$modifier', type '$type'\n";
    }

    $type =~ s/\s*\*$//; #kill whitespace "CHAR " isn't "CHAR"

    if (exists $Known{$type}) {
        if (defined $name and $name =~ s/\[(.*)\]$//) {
            $size    = $1;
            $packing = $Known{$type}[0] . "*" . $size;

            # DEBUG "(PM)Type::packing: composite packing: '$packing' '$size'\n";
        }
        else {
            $packing = $Known{$type};
            if ($is_pointer and ($packing eq 'c' or $packing eq 'S')) {
                $packing = "p";
            }

            # DEBUG "(PM)Type::packing: simple packing: '$packing'\n";
        }
        if (defined $modifier and exists $Modifier{$modifier}->{$type}) {

# DEBUG "(PM)Type::packing: applying modifier '$modifier' -> '$Modifier{$modifier}->{$type}'\n";
            $packing = $Modifier{$modifier}->{$type};
            if(!$pass_numeric) { #for older num unaware calls
                substr($packing, 0, length("num"), '');
            }
        }
        return $packing;
    }
    else {

        # DEBUG "(PM)Type::packing: NOT FOUND\n";
        return undef;
    }
}


sub is_pointer {
    my $self = shift;
    my $type = shift;
    $type = $self unless defined $type;
    if (ref($type) =~ /Win32::API::Type/) {
        return 1;
    }
    else {
        if ($type =~ /\*$/) {
            return 1;
        }
        else {
            return exists $Pointer{$type};
        }
    }
}

sub Pack {
    my $type = $_[1];

    my $pack_type = packing($type);
    #print "Pack: type $type pack_type $pack_type\n";
    if ($pack_type eq 'p') { #char or wide char pointer
        #$pack_type = 'Z*';
        return;
    }
    elsif(IVSIZE() == 4 && ($pack_type eq 'q' || $pack_type eq 'Q')){
        if($_[0]->UseMI64() || ref($_[2])){ #un/signed meaningless
            $_[2] = Math::Int64::int64_to_native($_[2]);
        }
        else{
            if(length($_[2]) < 8){
                warn("Win32::API::Call value for 64 bit integer is under 8 bytes long");
                $_[2] = pack('a8', $_[2]);
            }
        }
        return;
    }
    $_[2] = pack($pack_type, $_[2]);
    return;
}

sub Unpack {
    my $type = $_[1];

    my $pack_type = packing($type);

    if ($pack_type eq 'p') {
        DEBUG "(PM)Type::Unpack: got packing 'p': is a pointer\n" if DEBUGCONST;
        #$pack_type = 'Z*';
        return;
    }
    elsif(IVSIZE() == 4){
        #todo debugging output
        if($pack_type eq 'q'){
            if($_[0]->UseMI64() || ref($_[2])){
            $_[2] = Math::Int64::native_to_int64($_[2]);
            DEBUG "(PM)Type::Unpack: returning signed Math::Int64 '".$_[2]."'\n" if DEBUGCONST;
            }
            return;
        }elsif($pack_type eq 'Q'){
            if($_[0]->UseMI64() || ref($_[2])){
            $_[2] = Math::Int64::native_to_uint64($_[2]);
            DEBUG "(PM)Type::Unpack: returning unsigned Math::Int64 '".$_[2]."'\n" if DEBUGCONST;
            }
            return;
        }
    }
    DEBUG "(PM)Type::Unpack: unpacking '$pack_type' '$_[2]'\n" if DEBUGCONST;
    $_[2] = unpack($pack_type, $_[2]);
    DEBUG "(PM)Type::Unpack: returning '" . ($_[2] || '') . "'\n" if DEBUGCONST;
}

1;

#######################################################################
# DOCUMENTATION
#

#line 412


__DATA__

[TYPE]
ATOM					s
BOOL					L
BOOLEAN					c
BYTE					C
CHAR					c
COLORREF				L
DWORD                   L
DWORD32                 L
DWORD64                 Q
DWORD_PTR               _P
FLOAT                   f
HACCEL                  _P
HANDLE                  _P
HBITMAP                 _P
HBRUSH                  _P
HCOLORSPACE             _P
HCONV                   _P
HCONVLIST               _P
HCURSOR                 _P
HDC                     _P
HDDEDATA                _P
HDESK                   _P
HDROP                   _P
HDWP                    _P
HENHMETAFILE            _P
HFILE                   _P
HFONT                   _P
HGDIOBJ                 _P
HGLOBAL                 _P
HHOOK                   _P
HICON                   _P
HIMC                    _P
HINSTANCE               _P
HKEY                    _P
HKL                     _P
HLOCAL                  _P
HMENU                   _P
HMETAFILE               _P
HMODULE                 _P
HPALETTE                _P
HPEN                    _P
HRGN                    _P
HRSRC                   _P
HSZ                     _P
HWINSTA                 _P
HWND                    _P
INT                     i
INT32                   i
INT64                   q
LANGID                  s
LCID                    L
LCSCSTYPE               L
LCSGAMUTMATCH           L
LCTYPE                  L
LONG                    l
LONG32                  l
LONG64                  q
LONGLONG                q
LPARAM                  _P
LRESULT                 _P
NTSTATUS                l
REGSAM                  L
SC_HANDLE               _P
SC_LOCK                 _P
SERVICE_STATUS_HANDLE   _P
SHORT                   s
SIZE_T                  _P
SSIZE_T                 _P
TBYTE                   c
TCHAR                   C
UCHAR                   C
UINT                    I
UINT_PTR                _P
UINT32                  I
UINT64                  Q
ULONG                   L
ULONG32                 L
ULONG64                 Q
ULONGLONG               Q
USHORT                  S
WCHAR                   S
WORD                    S
WPARAM                  _P
VOID                    c

int                     i
long                    l
float                   f
double                  d
char                    c
short                   s
void                    c
__int64                 q

#VOID is a 'c'? huh?
#making void be a 'c' too, ~bulk88
#CRITICAL_SECTION   24 -- a structure
#LUID                   ?   8 -- a structure
#VOID   0
#CONST  4
#FILE_SEGMENT_ELEMENT   8 -- a structure

[PACKSIZE]
c   1
C   1
d   8
f   4
i   4
I   4
l   4
L   4
q   8
Q   8
s   2
S   2
p   _P
T   _P
t   _P

[MODIFIER]
unsigned    int=numI long=numL short=numS char=numC
signed      int=numi long=numl short=nums char=numc

[POINTER]
INT_PTR                 INT
LPBOOL                  BOOL
LPBYTE                  BYTE
LPCOLORREF              COLORREF
LPCSTR                  CHAR
#LPCTSTR                    CHAR or WCHAR
LPCTSTR                 CHAR
LPCVOID                 any
LPCWSTR                 WCHAR
LPDOUBLE                double
LPDWORD                 DWORD
LPHANDLE                HANDLE
LPINT                   INT
LPLONG                  LONG
LPSTR                   CHAR
#LPTSTR                 CHAR or WCHAR
LPTSTR                  CHAR
LPVOID                  VOID
LPWORD                  WORD
LPWSTR                  WCHAR

PBOOL                   BOOL
PBOOLEAN                BOOL
PBYTE                   BYTE
PCHAR                   CHAR
PCSTR                   CSTR
PCWCH                   CWCH
PCWSTR                  CWSTR
PDWORD                  DWORD
PFLOAT                  FLOAT
PHANDLE                 HANDLE
PHKEY                   HKEY
PINT                    INT
PLCID                   LCID
PLONG                   LONG
PSHORT                  SHORT
PSTR                    CHAR
#PTBYTE                 TBYTE --
#PTCHAR                 TCHAR --
#PTSTR                  CHAR or WCHAR
PTSTR                   CHAR
PUCHAR                  UCHAR
PUINT                   UINT
PULONG                  ULONG
PUSHORT                 USHORT
PVOID                   VOID
PWCHAR                  WCHAR
PWORD                   WORD
PWSTR                   WCHAR
char*                   CHAR
