# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

#######################################################################
#
# Win32::API - Perl Win32 API Import Facility
#
# Author: Aldo Calpini <dada@perl.it>
# Maintainer: Cosimo Streppone <cosimo@cpan.org>
#
# Changes for gcc/cygwin: Daniel Risacher <magnus@alum.mit.edu>
#  ported from 0.41 based on Daniel's patch by Reini Urban <rurban@x-ray.at>
#
#######################################################################

package Win32::API;
    use strict;
    use warnings;
BEGIN {
    require Exporter;      # to export the constants to the main:: space

    sub ISCYG ();
    if($^O eq 'cygwin') {
        BEGIN{warnings->unimport('uninitialized')}
        die "Win32::API on Cygwin requires the cygpath tool on PATH"
            if index(`cygpath --help`,'Usage: cygpath') == -1;
        require File::Basename;
        eval "sub ISCYG () { 1 }";
    } else {
        eval "sub ISCYG () { 0 }";
    }


    use vars qw( $DEBUG $sentinal @ISA @EXPORT_OK $VERSION );

    @ISA = qw( Exporter );
    @EXPORT_OK = qw( ReadMemory IsBadReadPtr MoveMemory
    WriteMemory SafeReadWideCString ); # symbols to export on request

    use Scalar::Util qw( looks_like_number weaken);
    
    sub ERROR_NOACCESS	() { 998 }
    sub ERROR_NOT_ENOUGH_MEMORY () { 8 }
    sub ERROR_INVALID_PARAMETER () { 87 }
    sub APICONTROL_CC_STD	() { 0 }
    sub APICONTROL_CC_C	() { 1 }
    sub APICONTROL_CC_mask  () { 0x7 }
    sub APICONTROL_UseMI64	() { 0x8 }
    sub APICONTROL_is_more	() { 0x10 }
    sub APICONTROL_has_proto() { 0x20 }
    eval ' *Win32::API::Type::PTRSIZE = *Win32::API::More::PTRSIZE = *PTRSIZE = sub () { '.length(pack('p', undef)).' };'.
          #Win64 added in 5.7.3
         ' *Win32::API::Type::IVSIZE = *Win32::API::More::IVSIZE = *IVSIZE = sub () { '.length(pack($] >= 5.007003 ? 'J' : 'I' ,0)).' };'.
         ' *Win32::API::Type::DEBUGCONST = *Win32::API::Struct::DEBUGCONST = *DEBUGCONST = sub () { '.(!!$DEBUG+0).' };'
}

sub DEBUG {
    #checking flag redundant now, but keep in case of an accidental unprotected call
    if ($Win32::API::DEBUG) {
        printf @_ if @_ or return 1;
    }
    else {
        return 0;
    }
}

use Win32::API::Type ();
use Win32::API::Struct ();

#######################################################################
# STATIC OBJECT PROPERTIES
#
#### some package-global hash to
#### keep track of the imported
#### libraries and procedures
my %Libraries  = ();
my %Procedures = ();


#######################################################################
# dynamically load in the API extension module.
# BEGIN required for constant subs in BOOT:
BEGIN {
    $VERSION = '0.84';
    require XSLoader;
    XSLoader::load 'Win32::API', $VERSION;
}

#######################################################################
# PUBLIC METHODS
#
sub new {
    die "Win32::API/More::new/Import is a class method that takes 2 to 6 parameters, see POD"
        if @_ < 3 || @_ > 7;
    my ($class, $dll, $hproc, $ccnum, $outnum) = (shift, shift);
    if(! defined $dll){
        $hproc = shift;
    }
    my ($proc, $in, $out, $callconvention) = @_;
    my ($hdll, $freedll, $proto, $stackunwind) = (0, 0, 0, 0);
    my $self = {};
    if(! defined $hproc){
        if (ISCYG() and $dll ne File::Basename::basename($dll)) {
    
            # need to convert $dll to win32 path
            # isn't there an API for this?
            my $newdll = `cygpath -w "$dll"`;
            chomp $newdll;
            DEBUG "(PM)new: converted '$dll' to\n  '$newdll'\n" if DEBUGCONST;
            $dll = $newdll;
        }
    
        #### avoid loading a library more than once
        if (exists($Libraries{$dll})) {
            DEBUG "Win32::API::new: Library '$dll' already loaded, handle=$Libraries{$dll}\n" if DEBUGCONST;
            $hdll = $Libraries{$dll};
        }
        else {
            DEBUG "Win32::API::new: Loading library '$dll'\n" if DEBUGCONST;
            $hdll = Win32::API::LoadLibrary($dll);
            $freedll = 1;
    #        $Libraries{$dll} = $hdll;
        }
    
        #### if the dll can't be loaded, set $! to Win32's GetLastError()
        if (!$hdll) {
            $! = Win32::GetLastError();
            DEBUG "FAILED Loading library '$dll': $^E\n" if DEBUGCONST;
            return undef;
        }
    }
    else{
        if(!looks_like_number($hproc) || IsBadReadPtr($hproc, 4)){
            Win32::SetLastError(ERROR_NOACCESS);
            DEBUG "FAILED Function pointer '$hproc' is not a valid memory location\n" if DEBUGCONST;
            return undef;
        }
    }
    #### determine if we have a prototype or not, outtype is for future use in XS
    if ((not defined $in) and (not defined $out)) {
        ($proc, $self->{in}, $self->{intypes}, $outnum, $self->{outtype},
         $ccnum) = parse_prototype($class, $proc);
        if( ! $proc ){
            Win32::API::FreeLibrary($hdll) if $freedll;
            Win32::SetLastError(ERROR_INVALID_PARAMETER);
            return undef;
        }
        $proto = 1;
    }
    else {
        $self->{in} = [];
        my $self_in = $self->{in}; #avoid hash derefing
        if (ref($in) eq 'ARRAY') {
            foreach (@$in) {
                push(@{$self_in}, $class->type_to_num($_));
            }
        }
        else {
            my @in = split '', $in;
            foreach (@in) {
                push(@{$self_in}, $class->type_to_num($_));
            }
        }#'V' must be one and ONLY letter for "in"
        foreach(@{$self_in}){
            if($_ == 0){ 
                if(@{$self_in} != 1){
                    Win32::API::FreeLibrary($hdll) if $freedll;
                    die "Win32::API 'V' for in prototype must be the only parameter";
                } else {undef(@{$self_in});} #empty arr, as if in param was ""
            }
        }
        $outnum   = $class->type_to_num($out, 1);
        $ccnum = calltype_to_num($callconvention);
    }

    if(!$hproc){ #if not non DLL func
        #### first try to import the function of given name...
        $hproc = Win32::API::GetProcAddress($hdll, $proc);
    
        #### ...then try appending either A or W (for ASCII or Unicode)
        if (!$hproc) {
            my $tproc = $proc;
            $tproc .= (IsUnicode() ? "W" : "A");
    
            # print "Win32::API::new: procedure not found, trying '$tproc'...\n";
            $hproc = Win32::API::GetProcAddress($hdll, $tproc);
        }
    
        #### ...if all that fails, give up, $! setting is back compat, $! is deprecated
        if (!$hproc) {
            my $err = $! = Win32::GetLastError();
            DEBUG "FAILED GetProcAddress for Proc '$proc': $^E\n" if DEBUGCONST;
            Win32::API::FreeLibrary($hdll) if $freedll;
            Win32::SetLastError($err);
            return undef;
        }
        DEBUG "GetProcAddress('$proc') = '$hproc'\n" if DEBUGCONST;
    }
    else {
        DEBUG "Using non-DLL function pointer '$hproc' for '$proc'\n" if DEBUGCONST;
    }
    if(PTRSIZE == 4 && $ccnum == APICONTROL_CC_C) {#fold out on WIN64
        #calculate add to ESP amount, in units of 4, will be *4ed later
        $stackunwind += $_ == T_QUAD || $_ == T_DOUBLE ? 2 : 1 for(@{$self->{in}});
        if($stackunwind > 0xFFFF) {
            goto too_many_in_params;
        }
    }
    # if a prototype has 8 byte types on 32bit, $stackunwind will be higher than
    # length of {in} letter array, so 2 different checks need to be done
    if($#{$self->{in}} > 0xFFFF) {
        too_many_in_params:
        DEBUG "FAILED This function has too many parameters (> ~65535) \n" if DEBUGCONST;
        Win32::API::FreeLibrary($hdll) if $freedll;
        Win32::SetLastError(ERROR_NOT_ENOUGH_MEMORY);
        return undef;
    }
    #### ok, let's stuff the object
    $self->{procname} = $proc;
    $self->{dll}      = $hdll;
    $self->{dllname}  = $dll;

    $outnum &= ~T_FLAG_NUMERIC;
    my $control;
    $self->{weakapi} = \$control;
    weaken($self->{weakapi});
    $control = pack(         'L'
                             .'L'
                             .(PTRSIZE == 8 ? 'Q' : 'L')
                             .(PTRSIZE == 8 ? 'Q' : 'L')
                             .(PTRSIZE == 8 ? 'Q' : 'L')
                             .(PTRSIZE == 8 ? '' : 'L')
                        ,($class eq "Win32::API::More" ? APICONTROL_is_more : 0)
                        | ($proto ? APICONTROL_has_proto : 0)
                        | $ccnum
                        | (PTRSIZE == 8 ? 0 :  $stackunwind << 8)
                        | $outnum << 24
                        , scalar(@{$self->{in}}) * PTRSIZE #in param count, in SV * units
                        , $hproc
                        , \($self->{weakapi})+0 #weak api obj ref
                        , (exists $self->{intypes} ? ($self->{intypes})+0 : 0)
                        , 0); #padding to align to 8 bytes on 32 bit only
    #align to 16 bytes
    $control .= "\x00" x ((((length($control)+ 15) >> 4) << 4)-length($control));
    #make a APIPARAM template array
    my ($i, $arr_end) = (0, scalar(@{$self->{in}}));
    for(; $i< $arr_end; $i++) {
        my $tin = $self->{in}[$i];
        #unsigned meaningless no sign vs zero extends are done bc uv/iv is
        #the biggest native integer on the cpu, big to small is truncation
        #numeric is implemented as T_NUMCHAR for in, keeps asm jumptable clean
        $tin &= ~(T_FLAG_UNSIGNED|T_FLAG_NUMERIC);
        $tin--; #T_VOID doesn't exist as in param in XS
        #put index of param array slice in unused space for croaks, why not?
        $control .= "\x00" x 8 . pack('CCSSS', $tin, 0, 0, $i, $i+1);
    }
    _Align($control, 16); #align the whole PVX to 16 bytes for SSE moves

    #### keep track of the imported function
    if(defined $dll){
        $Libraries{$dll} = $hdll;
        $Procedures{$dll}++;
    }
    DEBUG "Object blessed!\n" if DEBUGCONST;

    my $ref = bless(\$control, $class);
    SetMagicSV($ref, $self);
    return $ref;
}

sub Import {
    my $closure = shift->new(@_)
        or return undef;
    my $procname = ${Win32::API::GetMagicSV($closure)}{procname};
    #dont allow "sub main:: {0;}"
    Win32::SetLastError(ERROR_INVALID_PARAMETER), return undef if $procname eq '';
    _ImportXS($closure, (caller)[0].'::'.$procname);
    return $closure;
}

#######################################################################
# PRIVATE METHODS
#
sub DESTROY {
    my ($self) = GetMagicSV($_[0]);

    return if ! defined $self->{dllname};
    #### decrease this library's procedures reference count
    $Procedures{$self->{dllname}}--;

    #### once it reaches 0, free it
    if ($Procedures{$self->{dllname}} == 0) {
        DEBUG "Win32::API::DESTROY: Freeing library '$self->{dllname}'\n" if DEBUGCONST;
        Win32::API::FreeLibrary($Libraries{$self->{dllname}});
        delete($Libraries{$self->{dllname}});
    }
}

# Convert calling convention string (_cdecl|__stdcall)
# to a C const. Unknown counts as __stdcall
#
sub calltype_to_num {
    my $type = shift;

    if (!$type || $type eq "__stdcall" || $type eq "WINAPI" || $type eq "NTAPI"
        || $type eq "CALLBACK"  ) {
        return APICONTROL_CC_STD;
    }
    elsif ($type eq "_cdecl" || $type eq "__cdecl" || $type eq "WINAPIV") {
        return APICONTROL_CC_C;
    }
    else {
        warn "unknown calling convention: '$type'";
        return APICONTROL_CC_STD;
    }
}


sub type_to_num {
    die "wrong class" if shift ne "Win32::API";
    my $type = shift;
    my $out  = shift;
    my ($num, $numeric);
    if(index($type, 'num', 0) == 0){
        substr($type, 0, length('num'), '');
        $numeric = 1;
    }
    else{
        $numeric = 0;
    }

    if (   $type eq 'N'
        or $type eq 'n'
        or $type eq 'l'
        or $type eq 'L'
        or ( PTRSIZE == 8  and $type eq 'Q' || $type eq 'q'))
    {
        $num = T_NUMBER;
    }
    elsif ($type eq 'P'
        or $type eq 'p')
    {
        $num = T_POINTER;
    }
    elsif ($type eq 'I'
        or $type eq 'i')
    {
        $num = T_INTEGER;
    }
    elsif ($type eq 'f'
        or $type eq 'F')
    {
        $num = T_FLOAT;
    }
    elsif ($type eq 'D'
        or $type eq 'd')
    {
        $num = T_DOUBLE;
    }
    elsif ($type eq 'c'
        or $type eq 'C')
    {
        $num = $numeric ? T_NUMCHAR : T_CHAR;
    }
    elsif (PTRSIZE == 4 and $type eq 'q' || $type eq 'Q')
    {
        $num = T_QUAD;
    }
    elsif($type eq '>'){
        die "Win32::API does not support pass by copy structs as function arguments";
    }
    else {
        $num = T_VOID; #'V' takes this branch, which is T_VOID in C
    }#not valid return types of the C func
    if(defined $out) {#b/B remains private/undocumented
        die "Win32::API invalid return type, structs and ".
        "callbacks as return types not supported"
            if($type =~ m/^s|S|t|T|b|B|k|K$/);
    }
    else {#in type
        if ($type eq 's' or $type eq 'S' or $type eq 't' or $type eq 'T')
        {
            $num = T_STRUCTURE;
        }
        elsif ($type eq 'b'
            or $type eq 'B')
        {
            $num = T_POINTERPOINTER;
        }
        elsif ($type eq 'k'
            or $type eq 'K')
        {
            $num = T_CODE;
        }
    }
    $num |= T_FLAG_NUMERIC if $numeric;
    return $num;
}

package Win32::API::More;

use vars qw( @ISA );
@ISA = qw ( Win32::API );
sub type_to_num {
    die "wrong class" if shift ne "Win32::API::More";
    my $type = shift;
    my $out  = shift;
    my ($num, $numeric);
    if(index($type, 'num', 0) == 0){
        substr($type, 0, length('num'), '');
        $numeric = 1;
    }
    else{
        $numeric = 0;
    }

    if (   $type eq 'N'
        or $type eq 'n'
        or $type eq 'l'
        or $type eq 'L'
        or ( PTRSIZE == 8  and $type eq 'Q' || $type eq 'q')
        or (! $out and  # in XS short 'in's are interger/numbers code
            $type eq 'S'
            || $type eq 's'))
    {
        $num = Win32::API::T_NUMBER;
        if(defined $out && ($type eq 'N' || $type eq 'L'
                        ||  $type eq 'S' || $type eq 'Q')){
            $num |= Win32::API::T_FLAG_UNSIGNED;
        }
    }
    elsif ($type eq 'P'
        or $type eq 'p')
    {
        $num = Win32::API::T_POINTER;
    }
    elsif ($type eq 'I'
        or $type eq 'i')
    {
        $num = Win32::API::T_INTEGER;
        if(defined $out && $type eq 'I'){
            $num |= Win32::API::T_FLAG_UNSIGNED;
        }
    }
    elsif ($type eq 'f'
        or $type eq 'F')
    {
        $num = Win32::API::T_FLOAT;
    }
    elsif ($type eq 'D'
        or $type eq 'd')
    {
        $num = Win32::API::T_DOUBLE;
    }
    elsif ($type eq 'c'
        or $type eq 'C')
    {
        $num = $numeric ? Win32::API::T_NUMCHAR : Win32::API::T_CHAR;
        if(defined $out && $type eq 'C'){
            $num |= Win32::API::T_FLAG_UNSIGNED;
        }
    }
    elsif (PTRSIZE == 4 and $type eq 'q' || $type eq 'Q')
    {
        $num = Win32::API::T_QUAD;
        if(defined $out && $type eq 'Q'){
            $num |= Win32::API::T_FLAG_UNSIGNED;
        }
    }
    elsif ($type eq 's') #4 is only used for out params
    {
        $num = Win32::API::T_SHORT;
    }
    elsif ($type eq 'S')
    {
        $num = Win32::API::T_SHORT | Win32::API::T_FLAG_UNSIGNED;
    }
    elsif($type eq '>'){
        die "Win32::API does not support pass by copy structs as function arguments";
    }
    else {
        $num = Win32::API::T_VOID; #'V' takes this branch, which is T_VOID in C
    } #not valid return types of the C func
    if(defined $out) {#b/B remains private/undocumented
        die "Win32::API invalid return type, structs and ".
        "callbacks as return types not supported"
            if($type =~ m/^t|T|b|B|k|K$/);
    }
    else {#in type
        if (   $type eq 't'
            or $type eq 'T')
        {
            $num = Win32::API::T_STRUCTURE;
        }
        elsif ($type eq 'b'
            or $type eq 'B')
        {
            $num = Win32::API::T_POINTERPOINTER;
        }
        elsif ($type eq 'k'
            or $type eq 'K')
        {
            $num = Win32::API::T_CODE;
        }
    }
    $num |= Win32::API::T_FLAG_NUMERIC if $numeric;
    return $num;
}
package Win32::API;

sub parse_prototype {
    my ($class, $proto) = @_;

    my @in_params = ();
    my @in_types  = (); #one day create a BNF-ish formal grammer parser here
    if ($proto =~ /^\s*((?:(?:un|)signed\s+|) #optional signedness
        \S+)(?:\s*(\*)\s*|\s+) #type and maybe a *
        (?:(\w+)\s+)? # maybe a calling convention
        (\S+)\s* #func name
        \(([^\)]*)\) #param list
        /x) {
        my $ret            = $1.(defined($2)?$2:'');
        my $callconvention = $3;
        my $proc           = $4;
        my $params         = $5;

        $params =~ s/^\s+//;
        $params =~ s/\s+$//;

        DEBUG "(PM)parse_prototype: got PROC '%s'\n",   $proc if DEBUGCONST;
        DEBUG "(PM)parse_prototype: got PARAMS '%s'\n", $params if DEBUGCONST;
        
        foreach my $param (split(/\s*,\s*/, $params)) {
            my ($type, $name);
            #match "in_t* _var" "in_t * _var" "in_t *_var" "in_t _var" "in_t*_var" supported
            #unsigned or signed or nothing as prefix supported
            # "in_t ** _var" and "const in_t* var" not supported
            if ($param =~ /((?:(?:un|)signed\s+|)\w+)(?:\s*(\*)\s*|\s+)(\w+)/) {
                ($type, $name) = ($1.(defined($2)? $2:''), $3);
            }
            {
                BEGIN{warnings->unimport('uninitialized')}
                if($type eq '') {goto BADPROTO;} #something very wrong, bail out
            }
            my $packing = Win32::API::Type::packing($type);
            if (defined $packing && $packing ne '>') {
                if (Win32::API::Type::is_pointer($type)) {
                    DEBUG "(PM)parse_prototype: IN='%s' PACKING='%s' API_TYPE=%d\n",
                        $type,
                        $packing,
                        $class->type_to_num('P') if DEBUGCONST;
                    push(@in_params, $class->type_to_num('P'));
                }
                else {
                    DEBUG "(PM)parse_prototype: IN='%s' PACKING='%s' API_TYPE=%d\n",
                        $type,
                        $packing,
                        $class->type_to_num(Win32::API::Type->packing($type, undef, 1)) if DEBUGCONST;
                    push(@in_params, $class->type_to_num(Win32::API::Type->packing($type, undef, 1)));
                }
            }
            elsif (Win32::API::Struct::is_known($type)) {
                DEBUG "(PM)parse_prototype: IN='%s' PACKING='%s' API_TYPE=%d\n",
                    $type, 'T', Win32::API::More->type_to_num('T') if DEBUGCONST;
                push(@in_params, Win32::API::More->type_to_num('T'));
            }
            else {
                warn
                    "Win32::API::parse_prototype: WARNING unknown parameter type '$type'";
                push(@in_params, $class->type_to_num('I'));
            }
            push(@in_types, $type);

        }
        DEBUG "parse_prototype: IN=[ @in_params ]\n" if DEBUGCONST;


        if (Win32::API::Type::is_known($ret)) {
            if (Win32::API::Type::is_pointer($ret)) {
                DEBUG "parse_prototype: OUT='%s' PACKING='%s' API_TYPE=%d\n",
                    $ret,
                    Win32::API::Type->packing($ret),
                    $class->type_to_num('P') if DEBUGCONST;
                return ($proc, \@in_params, \@in_types, $class->type_to_num('P', 1),
                    $ret, calltype_to_num($callconvention));
            }
            else {
                DEBUG "parse_prototype: OUT='%s' PACKING='%s' API_TYPE=%d\n",
                    $ret,
                    Win32::API::Type->packing($ret),
                    $class->type_to_num(Win32::API::Type->packing($ret, undef, 1), 1) if DEBUGCONST;
                return (
                    $proc, \@in_params, \@in_types,
                    $class->type_to_num(Win32::API::Type->packing($ret, undef, 1), 1),
                    $ret, calltype_to_num($callconvention)
                );
            }
        }
        else {
            warn
                "Win32::API::parse_prototype: WARNING unknown output parameter type '$ret'";
            return ($proc, \@in_params, \@in_types, $class->type_to_num('I', 1),
                $ret, calltype_to_num($callconvention));
        }

    }
    else {
        BADPROTO:
        warn "Win32::API::parse_prototype: bad prototype '$proto'";
        return undef;
    }
}

#
# XXX hack, see the proper implementation in TODO
# The point here is don't let fork children free the parent's DLLs.
# CLONE runs on ::API and ::More, that's bad and causes a DLL leak, make sure
# CLONE dups the DLL handles only once per CLONE
# GetModuleHandleEx was not used since that is a WinXP and newer function, not Win2K.
# GetModuleFileName was used to get full DLL pathname incase SxS/multiple DLLs
# with same file name exist in the process. Even if the dll was loaded as a
# relative path initially, later SxS can load a DLL with a different full path
# yet same file name, and then LoadLibrary'ing the original relative path
# might increase the refcount on the wrong DLL or return a different HMODULE
sub CLONE { 
    return if $_[0] ne "Win32::API";
    
    _my_cxt_clone();
    foreach( keys %Libraries){
        if($Libraries{$_} != Win32::API::LoadLibrary(Win32::API::GetModuleFileName($Libraries{$_}))){
            die "Win32::API::CLONE unable to clone DLL \"$Libraries{$_}\" Unicode Problem??";
        }
    }
}

1;

__END__

#######################################################################
# DOCUMENTATION
#

#line 1474

