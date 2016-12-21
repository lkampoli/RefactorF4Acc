package CallHaskellWrappers::f1;
use Exporter qw( import );
@CallHaskellWrappers::f1::EXPORT = qw( f1 );

use Call::Haskell::ReadShow qw( showH readH );       
use Types;
use AlgType;
require Call::Haskell; 
sub f1 {
    my $hs_type='AlgType';
#    my $in_str = '';
    my @in_arg_strs=();
    for my $arg (@_) {
        if (ref($arg) eq 'Types') {    
            push @in_arg_strs, Types::show($arg);
        } else {
           push @in_arg_strs,  Call::Haskell::ReadShow::showH($arg,$hs_type);
        }
    }
    my $in_str = (@_>1) ? '('.join(', ',@in_arg_strs).')' : $in_arg_strs[0];     
    my $out_str=Call::Haskell::f1_ser($in_str);    
    my $res = eval($out_str);
    return $res;
}

1;