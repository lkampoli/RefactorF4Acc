package RefactorF4Acc::CTranslation;
use v5.016;
# THIS SUBROUTINE IS CURRENTLY OBSOLETE, WE USE OpenCLTranslation INSTEAD
use RefactorF4Acc::Config;
use RefactorF4Acc::Utils;
# 
#   (c) 2010-2012 Wim Vanderbauwhede <wim@dcs.gla.ac.uk>
#   

use vars qw( $VERSION );
$VERSION = "1.0.0";

use warnings::unused;
use warnings;
use warnings FATAL => qw(uninitialized);
use strict;
use Carp;
use Data::Dumper;

use Exporter;

@RefactorF4Acc::CTranslation::ISA = qw(Exporter);

@RefactorF4Acc::CTranslation::EXPORT_OK = qw(
    &add_to_C_build_sources
    &translate_to_C

);
#    &translate_all_to_C        
#    &refactor_C_targets
#    &emit_C_targets
#    &toCType

## So assuming a subroutine has been marked with 
# if (exists $stref->{'Subroutines'}{$sub}{'Translate'} and $stref->{'Subroutines'}{$sub}{'Translate'} eq 'C') {
# 	# Then we can emit C code 
# 		translate_sub_to_C($stref,$sub);
# }

#### #### #### #### BEGIN OF C TRANSLATION CODE #### #### #### ####
sub translate_to_C {  (my $stref, my $f) = @_;
=info	
	# First we collect info. What we need to know is:
	
	- What are the subroutine arguments, and their types?
	- Scalar && IODir eq 'In' => emit a scalar
	- otherwise => emit a pointer
	- make a list/table of all the arguments, of course we already have that in $stref->{'Subroutines'}{$f}{'RefactoredArgs'}
	- Then for every VarDecl we encounter:
		- if it's an Arg, remove it
		- otherwise, convert it to C syntax
		- In any case, if it is an array, we need the dimensions; but that should exists already in $stref->{'Subroutines'}{$f}{'Vars'}
	- If we find a select/case, we need to mark the *first* case to indicate that it should *not* be prefixed with  "}\n break;"
	- so maybe we actually don't need a separate pass after all ...
		 		
=cut
	my $pass_translate_to_C = sub { (my $annline, my $state)=@_;
		(my $line,my $info)=@{$annline};
		my $c_line=$line;
		(my $stref, my $f, my $pass_state)=@{$state};
#		say Dumper($stref->{'Subroutines'}{$f}{'DeletedArgs'});
		my $skip=0;
		if (exists $info->{'Signature'} ) {
			$c_line = _emit_subroutine_sig_C( $stref, $f, $annline);
		}
		elsif (exists $info->{'VarDecl'} ) {
				my $var = $info->{'VarDecl'}{'Name'};
				if (exists $stref->{'Subroutines'}{$f}{'RefactoredArgs'}{'Set'}{$var}
				) {
					$c_line='//'.$line;
					$skip=1;
				} else {
									
					$c_line = _emit_var_decl_C($stref,$f,$var); 
				}
		}
		elsif ( exists $info->{'ParamDecl'} ) {
				my $var = $info->{'VarDecl'}{'Name'};

				$c_line = _emit_var_decl_C($stref,$f,$var); 		
		}
		elsif (exists $info->{'Select'} ) {				
#			$c_line=$line;
#			$c_line=~s/select\s+case/switch/;
#			$c_line.='{';
			my $switch_expr = _emit_expression_C(['$',$info->{'CaseVar'}],'',$stref,$f);
			$c_line ="switch ( $switch_expr ) {";
		}
		elsif (exists $info->{'Case'} ) {
			$c_line=$line.': {';#'case';
			if ($info->{'Case'}>1) {
				$c_line = $info->{'Indent'}."} break;\n".$info->{'Indent'}.$c_line;
			}
		}
		elsif (exists $info->{'CaseDefault'}) {
			$c_line = $info->{'Indent'}."} break;\n".$info->{'Indent'}.'default : {';
		}
		elsif (exists $info->{'BeginDo'} ) {
				$c_line='for () {'; 
		}
		if (exists $info->{'Assignment'} ) {
				$c_line = _emit_assignment_C($stref, $f, $info).';';
		}
		elsif (exists $info->{'SubroutineCall'} ) {
			# 
			my $subcall_ast = $info->{'SubroutineCall'}{'ExpressionAST'};
			$subcall_ast->[0] = '&';
			# There is an issue here:
			# We actually need to check the type of the called arg against the type of the sig arg
			# If the called arg is a pointer and the sig arg is a pointer, no '*', else, we need a '*'
			# But the problem is of course that we have just replaced the called args by the sig args
			# So what we need to do is check the type in $f and $subname, and use that to see if we need a '*' or even an '&' or nothing
			$c_line = _emit_expression_C($subcall_ast,'',$stref,$f).';';
			if ($c_line=~/get_get_global_id/) {
				$c_line = "global_id = get_global_id(0);";
			}
		}			 
		elsif (exists $info->{'If'} ) {		
			$c_line = _emit_ifthen_C($stref, $f, $info);
		}
		elsif (exists $info->{'ElseIf'} ) {		
			$c_line = '} else '._emit_ifthen_C($stref, $f, $info);
		}
		elsif (exists $info->{'Else'} ) {		
			$c_line = ' } else {';
		}
		elsif (exists $info->{'EndDo'} or exists $info->{'EndIf'}  or exists $info->{'EndSubroutine'} ) {
				 $c_line = '}';
		}
		elsif (exists $info->{'EndSelect'} ) {
				 $c_line = '    }'."\n".$info->{'Indent'}.'}';
		}
		
		elsif (exists $info->{'Comments'} ) {
			$c_line = $line;
			$c_line=~s/\!/\/\//;
		}
		elsif (exists $info->{'Use'} or
		exists $info->{'ImplicitNone'} or
		exists $info->{'Implicit'}		
		) {
			$c_line = '//'.$line; $skip=1;
		}	
		elsif (exists $info->{'Include'} ) {
			$line=~s/^\s*$//;
			$c_line = '#'.$line;
		}
		elsif (exists $info->{'Goto'} ) {
			$c_line = $line.';';
		}
		elsif (exists $info->{'Continue'}) {
			$c_line='';
		}
		if (exists $info->{'Label'} ) {
			$c_line = $info->{'Label'}. ' : '."\n".$info->{'Indent'}.$c_line;
		}
		
		push @{$pass_state->{'TranslatedCode'}},$info->{'Indent'}.$c_line unless $skip;
		
		return ([$annline],[$stref,$f,$pass_state]);
	};

	my $state = [$stref,$f,{'TranslatedCode'=>[]}];
 	($stref,$state) = stateful_pass($stref,$f,$pass_translate_to_C, $state,'C_translation_collect_info() ' . __LINE__  ) ;
 	map {say $_ } @{$state->[2]{'TranslatedCode'}};
 	return $stref;
	
} # END of translate_to_C()

sub _emit_subroutine_sig_C { (my $stref, my $f, my $annline)=@_;
#	say "//SUB $f";
	    (my $line, my $info) = @{ $annline };
	    my $Sf        = $stref->{'Subroutines'}{$f};
	    
	    my $name = $info->{'Signature'}{'Name'};
#	    say "NAME $name";
		my $args_ref = $info->{'Signature'}{'Args'}{'List'};
		my $c_args_ref=[];	    			
		for my $arg (@{ $args_ref }) {
			($stref,my $c_arg_decl) = _emit_arg_decl_C($stref,$f,$arg);
			push @{$c_args_ref},$c_arg_decl;
		}
#g => {'Dim' => [['1','1']],'ArrayOrScalar' => 'Array','Name' => 'g_ptr','IODir' => undef,'Type' => 'real','Indent' => '    ','Attr' => ''}
#eta_j_k_ => {'Dim' => [],'ArrayIndexExpr' => 'eta(j+1,k)','Type' => 'real','IODir' => 'in','Attr' => '','ArrayOrScalar' => 'Scalar','Name' => 'eta','Indent' => '    '}	    
	    my $args_str = join( ',', @{$c_args_ref} );	    
	    my $rline = "void $name($args_str) {\n";
		return  $rline;
}

sub _emit_arg_decl_C { (my $stref,my $f,my $arg)=@_;
#	my $decl =	$stref->{'Subroutines'}{$f}{'RefactoredArgs'}{'Set'}{$arg};
say $f;
	my $decl =	get_var_record_from_set($stref->{'Subroutines'}{$f}{'Vars'},$arg); say  $arg.'<'.Dumper($decl).'>';
	my $array = $decl->{'ArrayOrScalar'} eq 'Array' ? 1 : 0;
	my $const = 1;
	if (not defined $decl->{'IODir'}) {
		$const = 0;
	} else { 
		$const =    lc($decl->{'IODir'}) eq 'in' ? 1 : 0;
	}
	my $ptr = ($array || ($const==0)) ? '*' : '';
	croak $f.Dumper($decl).$ptr if $arg eq 'etan_j_k_';
	$stref->{'Subroutines'}{$f}{'Pointers'}{$arg}=$ptr;	
	my $ftype = $decl->{'Type'};
	my $fkind = $decl->{'Attr'};
	$fkind=~s/\(kind=//;
	$fkind=~s/\)//;
	if ($fkind eq '') {$fkind=4};
	my $c_type = toCType($ftype,$fkind);
	my $c_arg_decl = $c_type.' '.$ptr.$arg;
	return ($stref,$c_arg_decl);
}



sub _emit_var_decl_C { (my $stref,my $f,my $var)=@_;
	my $decl =  get_var_record_from_set($stref->{'Subroutines'}{$f}{'Vars'},$var);
#		carp "SUB $f => VAR $var =>".Dumper($decl);
# {'Var' => 'st_sub_map_124','Status' => 1,'Dim' => [],'Attr' => '','Type' => {'Type' => 'integer'},'Val' => '0','Indent' => '  ','Name' => ['st_sub_map_124','0'],'InheritedParams' => undef,'Parameter' => 'parameter'}		
	my $array = (exists $decl->{'ArrayOrScalar'} and $decl->{'ArrayOrScalar'} eq 'Array') ? 1 : 0;
	my $const = '';
	my $val='';
	if (defined $decl->{'Parameter'}) {
		$const = 'const ';
		$val = ' = '.$decl->{'Val'};
	}
	my $ptr = $array  ? '*' : '';
	$stref->{'Subroutines'}{$f}{'Pointers'}{$var}=$ptr;
	my $ftype = $decl->{'Type'};
	my $fkind = $decl->{'Attr'};
#	carp Dumper($fkind);
	if (ref ($ftype) eq 'HASH') {		
		if (exists $ftype->{'Kind'}) {
			$fkind = $ftype->{'Kind'};
		}
		$ftype = $ftype->{'Type'};
	}
	$fkind=~s/\(kind=//;
	$fkind=~s/\)//;
	if ($fkind eq '') {$fkind=4};
	
	my $c_type = toCType($ftype,$fkind);
	my $c_var_decl = $const.$c_type.' '.$ptr.$var.$val.';';
	return ($stref,$c_var_decl);
}

sub _emit_assignment_C { (my $stref, my $f, my $info)=@_;
	my $lhs_ast =  $info->{'Lhs'}{'ExpressionAST'};
#	say Dumper($lhs_ast);
	my $lhs = _emit_expression_C($lhs_ast,'',$stref,$f);
	$lhs=~s/\(([^\(\)]+)\)/$1/;
	my $rhs_ast =  $info->{'Rhs'}{'ExpressionAST'};	
#	carp Dumper($rhs_ast) if $lhs=~/k_range/;

	my $rhs = _emit_expression_C($rhs_ast,'',$stref,$f);
#	say "RHS:$rhs" if$rhs=~/abs/;
	my $rhs_stripped = $rhs;
	$rhs_stripped=~s/^\(([^\(\)]+)\)$/$1/;
#	say "RHS STRIPPED:$rhs_stripped" if$rhs=~/abs/;
#	$rhs_stripped=~s/^\(// && $rhs_stripped=~s/\)$//;
#	if ( $rhs_stripped=~/[\(\)]/) {
#		# Undo!
#		$rhs_stripped=$rhs;
#	}
#	say $rhs_stripped;
	my $rline = $info->{'Indent'}.$lhs.' = '.$rhs_stripped;
	if (exists $info->{'If'}) {
		my $if_str = _emit_ifthen_C($stref,$f,$info);
		$rline =$if_str.' '.$rline; 
	}	
	return $rline;
}



sub _emit_ifthen_C { (my $stref, my $f, my $info)=@_;	
	my $cond_expr_ast=$info->{'CondExecExpr'};
	my $cond_expr = _emit_expression_C($cond_expr_ast,'',$stref,$f);
	$cond_expr=_change_operators_to_C($cond_expr);
	my $rline = 'if ('.$cond_expr.') '. (exists $info->{'IfThen'} ? '{' : '');
		
	return $rline;
}

sub _emit_expression_C {(my $ast, my $expr_str, my $stref, my $f)=@_;
#	carp Dumper($ast);
	if (ref($ast) ne 'ARRAY') {return $ast;}
	my @expr_chunks=();
	my $skip=0;
	
	for my  $idx (0 .. scalar @{$ast}-1) {		
		my $entry = $ast->[$idx];
		if (ref($entry) eq 'ARRAY') {
			 my $nest_expr_str = _emit_expression_C( $entry, '',$stref,$f);
#			 say "NEST:$nest_expr_str ";
			push @expr_chunks, $nest_expr_str;
		} else {
			if ($entry =~/#/) {
				$skip=1;
			} elsif ($entry eq '&') {
				my $mvar = $ast->[$idx+1];				
				$expr_str.=$mvar.'(';
				
				 $stref->{'CalledSub'}= $mvar;
				 
				$skip=1;
			} elsif ($entry eq '$') {
				my $mvar = $ast->[$idx+1];
#				carp $mvar;
				my $called_sub_name = $stref->{'CalledSub'} // '';
				if (exists $stref->{'Subroutines'}{$f}{'Pointers'}{$mvar} ) {
					# Meaning that $mvar is a pointer in $f
					# Now we need to check if it is also a pointer in $subname
					my $ptr = $stref->{'Subroutines'}{$f}{'Pointers'}{$mvar};
					if ($called_sub_name ne '' and exists  $stref->{'Subroutines'}{$called_sub_name} 
					and exists  $stref->{'Subroutines'}{$called_sub_name}{'Pointers'}{$mvar} ) {
						my $sig_ptr = $stref->{'Subroutines'}{$called_sub_name}{'Pointers'}{$mvar};
						if ($sig_ptr eq '' and $ptr eq '*') {
							$ptr = '*'	
						} elsif ($sig_ptr eq '*' and $ptr eq '') {
							$ptr = '&'
						} else {
							$ptr='';
						}
					}
					
					push @expr_chunks,  $ptr eq '' ? $mvar : '('.$ptr.$mvar.')';
				} else {
					push @expr_chunks,$mvar;
				}
				$skip=1;				
			} elsif ($entry eq '@') {
				
				my $mvar = $ast->[$idx+1];
				if ($mvar eq '_OPEN_PAR_') {
					$expr_str.=$mvar.'(';
				} elsif ($mvar eq 'abs') { croak;
					$expr_str.=$mvar.'(';					
				} else {
					my $decl = get_var_record_from_set($stref->{'Subroutines'}{$f}{'Vars'},$mvar);

					my $dims =  $decl->{'Dim'};
					
					my $dim = scalar @{$dims};
#					say $mvar . Dumper( $decl). ' => ' .$dim;
					my @ranges=();
					my @lower_bounds=();
					for my $boundspair (@{$dims}) {
						(my $lb, my $hb)=@{$boundspair };
						push @ranges, "(($hb - $lb )+1)";
						push @lower_bounds, $lb; 
					} 				
				# For convenience we define a different function, not FTNREF
				 # F3D2C(
#                        unsigned int iz,unsigned int jz, // ranges, i.e. (hb-lb)+1
#                                int i_lb, int j_lb, int k_lb, // lower bounds
#                int ix, int jx, int kx)
# with the same definition as FTN3DREF
					$expr_str.=$mvar.'[F'.$dim.'D2C('.join(',',@ranges).' , '.join(',',@lower_bounds). ' , ';
				}
				$skip=1;
			} elsif (
				$ast->[$idx-1]!~/^[\&\@\$]/ 
			) {
#				say "ENTRY:$entry SKIP: $skip";
				push @expr_chunks,$entry;
				$skip=0;
			}
		}				
	}
	if ($ast->[0] eq '&' ) {
		my @expr_chunks_stripped = map { $_=~s/^\(([^\(\)]+)\)$/$1/;$_} @expr_chunks; 
		$expr_str.=join(',',@expr_chunks_stripped);
		$expr_str.=')'; 
		if ($ast->[1]  eq $stref->{'CalledSub'} ) {
		$stref->{'CalledSub'} ='';
		}
#		say "CLOSE OF &:".$expr_str if $expr_str=~/abs/;
	} elsif ( $ast->[0] eq '@') {
		my @expr_chunks_stripped =   map {  $_=~s/^\(([^\(\)]+)\)$/$1/;$_} @expr_chunks;
		$expr_str.=join(',',@expr_chunks_stripped);
		# But here we'd need to know what the var is!
		$expr_str.=')';
		if ($expr_str=~/\[/) {
		$expr_str.=']'; 		
		} 
	} elsif ($ast->[0] ne '$' and $ast->[0] =~ /\W/) {
		my $op = $ast->[0];		
		if (scalar @{$ast} > 2) {
			my @ts=();
			for my $elt (1 .. scalar @{$ast} -1 ) {
				$ts[$elt-1] = (ref($ast->[$elt]) eq 'ARRAY') ? _emit_expression_C( $ast->[$elt], '',$stref,$f) : $ast->[$elt];					
			} 
			if ($op eq '^') {
				$op = '**';
				warn "TODO: should be pow()";
			};
			$expr_str.=join($op,@ts);
		} elsif (defined $ast->[2]) { croak "OBSOLETE!";
			my $t1 = (ref($ast->[1]) eq 'ARRAY') ? _emit_expression_C( $ast->[1], '',$stref,$f) : $ast->[1];
			my $t2 = (ref($ast->[2]) eq 'ARRAY') ? _emit_expression_C( $ast->[2], '',$stref,$f) : $ast->[2];			
			$expr_str.=$t1.$ast->[0].$t2;
			if ($ast->[0] ne '=') {
				$expr_str="($expr_str)";
			}			
		} else {
			# FIXME! UGLY!
			my $t1 = (ref($ast->[1]) eq 'ARRAY') ? _emit_expression_C( $ast->[1], '',$stref,$f) : $ast->[1];
			$expr_str=$ast->[0].$t1;
			if ($ast->[0] eq '/') {
				$expr_str='1.0'.$expr_str; 
			}
		}
	} else {
		$expr_str.=join(';',@expr_chunks);
	}	
#	$expr_str=~s/_complex_//g;
	$expr_str=~s/_OPEN_PAR_//g;
	$expr_str=~s/_LABEL_ARG_//g;
	if ($expr_str=~s/^\#dummy\#\(//) {
		$expr_str=~s/\)$//;
	}
	$expr_str=~s/\+\-/-/g;
	# UGLY! HACK to fix boolean operations
#	 say "BEFORE HACK:".$expr_str if $expr_str=~/abs/;
	while ($expr_str=~/__[a-z]+__/ or $expr_str=~/\.\w+\.\+/) {
		$expr_str =~s/\+\.(\w+)\.\+/\.${1}\./g;
		$expr_str =~s/\.(\w+)\.\+/\.${1}\./g;
		$expr_str =~s/__not__\+/\.not\./g; 
		$expr_str =~s/__not__/\.not\./g; 		
		$expr_str =~s/__false__/\.false\./g;
		$expr_str =~s/__true__/\.true\./g;
		$expr_str =~s/\+__(\w+)__\+/\.${1}\./g;		
		$expr_str =~s/__(\w+)__/\.${1}\./g;
#		  		$expr_str =~s/\.(\w+)\./$F95_ops{$1}/g;
	}	
#	say "AFTER HACK:".$expr_str if $expr_str=~/abs/;
	return $expr_str;		
} # END of _emit_expression_C()

sub _change_operators_to_C { (my $cond_expr) = @_;
	
my %C_ops =(
	'eq' => '==',
	'ne' => '!=',
	'le' => '<=',
	'ge' => '>=',
	'gt' => '>',
	'lt' => '<',
	'not' => '!',
	'and' => '&&',
	'or' => '||',	     			
);
while ($cond_expr=~/\.(\w+)\./) {	
	$cond_expr=~s/\.(\w+)\./$C_ops{$1}/;
}
	return $cond_expr;
}
#### #### #### #### END OF C TRANSLATION CODE #### #### #### ####
 
# -----------------------------------------------------------------------------

sub translate_to_C_OLD { croak 'OBSOLETE!';
	( my $stref ) = @_;
    $translate = $GO;
    for my $subname ( keys %{ $stref->{'SubsToTranslate'} }) {
        print "\nTranslating $subname to C\n" if $V;
        $gen_sub  = 1;
        $stref = parse_fortran_src( $subname, $stref );
        $stref = refactor_C_targets($stref);
        emit_C_targets($stref);
        translate_sub_to_C($stref);
    }
	return $stref;
} # END of translate_to_C_OLD()
#  -----------------------------------------------------------------------------
sub refactor_C_targets { croak 'OBSOLETE!';
    ( my $stref ) = @_;
    print "\nREFACTORING C TARGETS\n";

    #   print Dumper(keys %{ $stref->{'Subroutines'} });
    for my $f ( keys %{ $stref->{'Subroutines'} } ) {
        my $Sf = $stref->{'Subroutines'}{$f};
        if ( exists $stref->{'BuildSources'}{'C'}{ $Sf->{'Source'} } ) {
            $stref = refactor_subroutine_main( $f, $stref );
        }
    }
    return $stref;
}    # END of refactor_C_targets()

# -----------------------------------------------------------------------------
sub emit_C_targets { croak 'OBSOLETE!';
    ( my $stref ) = @_;
    print "\nEMITTING C TARGETS\n";
    for my $f ( keys %{ $stref->{'Subroutines'} } ) {
        if (
            exists $stref->{'BuildSources'}{'C'}
            { $stref->{'Subroutines'}{$f}{'Source'} } )
        {
            emit_refactored_subroutine( $f, $targetdir, $stref, 1 );
        }
    }
}    # END of emit_C_targets()
# -----------------------------------------------------------------------------
sub translate_all_to_C { croak 'OBSOLETE!';
    ( my $stref ) = @_;
    local $V=1;
my $T=1;
# At first, all we do is get the call tree and translate all sources to C with F2C_ACC
# The next step is to fix the bugs in F2C_ACC via post-processing (later maybe actually debug F2C_ACC)
    chdir $targetdir;
    print "\n", "=" x 80, "\n" if $V;
    print "TRANSLATING TO C\n\n" if $V;
    print `pwd`                  if $V;
    foreach my $csrc ( keys %{ $stref->{'BuildSources'}{'C'} } ) {
        if ( -e $csrc ) {
            my $cmd = "f2c $csrc";
            print $cmd, "\n" if $V;
            system($cmd) if $T;
        } else {
            print "WARNING: $csrc does not exist\n" if $W;
        }
    }

# A minor problem is that we need to translate all includes contained in the tree as well
    foreach my $inc ( keys %{ $stref->{'BuildSources'}{'H'} } ) {
        my $cmd = "f2c $inc -H"; # FIXME: includes need -I support! NOTE $inc , not ./$inc, bug in F2C_ACC
        print $cmd, "\n" if $V;
        system($cmd) if $T;
    }
    
    my $i = 0;
    print "\nPOSTPROCESSING C CODE\n\n";
    foreach my $csrc ( keys %{ $stref->{'BuildSources'}{'C'} } ) {
        $csrc =~ s/\.f/\.c/;
         if ($T) {
            postprocess_C( $stref, $csrc, $i );
         } else {
         	print "postprocess_C( \$stref, $csrc, $i );\n";
         }
        $i++;
    }

    # Test the generated code
    print "\nTESTING C CODE\n\n";
    foreach my $ii ( 0 .. $i - 1 ) {
        my $cmd = 'gcc -Wall -c -I$GPU_HOME/include tmp' . $ii . '.c';
        print $cmd, "\n" if $V;
        system $cmd if $T;
    }

}    # END of translate_all_to_C()

# -----------------------------------------------------------------------------
# We need a separate pass I think to get the C function signatures
# Then we need to change all array accesses used as arguments to pointers:
# a[i] => a+i
# Every arg in C must be a pointer (FORTRAN uses pass-by-ref)
# So any arg in a call that is not a pointer is wrong
# We can assume that if the arg is say v and v__G exists, then
# it should be v__G
# vdepo[FTNREF1D(i,1)] => vdepo+FTNREF1D(i,1)
#
# Next, we need to figure out which arguments can remain non-pointer scalars
# That means:
# - parse the C function signature
# - find corresponding arguments in the FORTRAN signature
# - if they are Input Scalar, don't make them pointers
# - in that case, comment out the corresponding "int v = *v__G;" line

#WV04032012: TODO: this is hideous, need to refactor it into multiple functions and make more logical/robust! 
sub postprocess_C { croak 'OBSOLETE!';
    ( my $stref, my $csrc, my $i ) = @_;
    print "POSTPROC $csrc\n";
    my $sub           = '';
    my $argstr        = '';
    my %params        = ();
    my %vars          = ();
    my %argvars       = ();
    my %labels        = ();
    my %input_scalars = ();

    ### Local functions
    
    # We need to check if this particular label is a Break
    # So we need a list of all labels per subroutine.
    my $isBreak = sub {
        ( my $label ) = @_;
        return ( $labels{$label} eq 'BreakTarget'
              || $labels{$label} eq 'NoopBreakTarget' );
    };

    my $isNoop = sub {
        ( my $label ) = @_;
        return ( $labels{$label} eq 'NoopBreakTarget' );
    };

    open my $CSRC,   '<', $csrc; # FIXME: need PATH support
    open my $PPCSRC, '>', 'tmp' . $i . '.c';    # FIXME
    my $skip = 0;
    my $skipline = 0;
    while ( my $line = <$CSRC> ) {
        my $decl = '';
        $line=~/^\#define\ FALSE/ && do {
        	$skipline=1;
        	print $PPCSRC $line;
            next;
        }; 
        if ($line=~/^\#define\s+(\w+)/ ) {
        	my $par=$1;
        	if ( exists $stref->{'Subroutines'}{$sub}{'Parameters'}{'Set'}{$par} ) { # FIXME!i
                $skipline=0;
        	}
        }; 
        if ($line=~/^\s*\/\//) {
        	print $PPCSRC $line;
        	next;
        }
        $line=~/^\s*$/ && next;
        # Rewrite the subroutine signature. Not sure if this is still required, skip for now.
        $line =~ /^\s*void\s+(\w+)_\s+\(\s*(.*?)\s*\)\s+\{/ && do {
        	$skipline=0;
            $sub    = $1;
            $argstr = $2;
            my $Ssub = $stref->{'Subroutines'}{$sub};
            my @args = split( /\s*\,\s*/, $argstr );

            %argvars = map {
                s/^\w+\s+\*?//;
                s/^F2C-ACC.*?\.\s+\*?//;
                $_ => 1;
            } @args;

            for my $i ( keys %{ $Ssub->{'Includes'} } ) {
                if ( $stref->{'IncludeFiles'}{$i}{'InclType'} eq 'Parameter' ) {
                    %params = (
                        %params, %{ $stref->{'IncludeFiles'}{$i}{'Parameters'}{'Set'} }
                    );
                }
            }
            %vars = %{ $Ssub->{'Vars'} };
            for my $arg (@args) {
                $arg =~ s/^\w+\s+\*//;
                $arg =~ s/^F2C-ACC.*?\.\s+\*?//;
                my $var = $arg;
                $var =~ s/__G//;
                if ( exists $vars{$var} and $vars{$var}{'Type'} ) {
                    my $ftype = $vars{$var}{'Type'};
                    my $ctype = toCType($ftype);
#                    print Dumper($Ssub->{'RefactoredArgs'}{'Set'});
                    my $iodir = $Ssub->{'RefactoredArgs'}{'Set'}{$var}{'IODir'};
                    my $kind  = $vars{$var}{'ArrayOrScalar'};

                    if ( $iodir eq 'In' and $kind eq 'Scalar' ) {
                        $arg = "$ctype $var";
                    } else {
                        $arg = "$ctype *$arg";
                    }
                } else {
                    die "No entry for $var in $sub\n" . Dumper(%vars);
                }
            }
            $line = "\t void ${sub}_( " . join( ',', @args ) . " ){\n";

            %labels = ();
            if ( exists $Ssub->{'Gotos'} ) {
                %labels = %{ $Ssub->{'Gotos'} };
            }
            # Create a header file with declarations
            $decl = $line;
            $decl =~ s/\{.*$/;/;
            my $hfile = "$sub.h";            
            open my $INC, '>', $hfile;
            my $shield = $hfile;
            $shield =~ s/\./_/;
            $shield = '_' . uc($shield) . '_';
            print $INC '#ifndef ' . $shield . "\n";
            print $INC '#define ' . $shield . "\n";
            print $INC $decl, "\n";
            print $INC '#endif //' . $shield . "\n";
            close $INC;

            $skip = 1;
        }; # signature
        
        # This too might be obsolete, or at least "TODO"
        $line =~ /(\w+)=\*(\w+)__G;/ && do {
            if ( $1 eq $2 ) {
                my $var = $1;
                my $iodir =
                  $stref->{'Subroutines'}{$sub}{'RefactoredArgs'}{'Set'}{$var}
                  {'IODir'};
                my $kind = $vars{$var}{'ArrayOrScalar'};
                if ( $iodir eq 'In' and $kind eq 'Scalar' ) {
                    $line =~ s|^|\/\/|;
                    $input_scalars{ $var . '__G' } = $var;
                }
            }
        };
        # Fix translation errors
        $line =~ /F2C\-ACC\:\ Type\ not\ recognized\./ && do {
            my @chunks = split( /\,/, $line );
            for my $chunk (@chunks) {
                $chunk =~ /F2C\-ACC\:\ Type\ not\ recognized\.\ \*?(\w+)/
                  && do {
                    my $var = $1;
                    $var =~ s/__G//;
                    if ( exists $vars{$var} and $vars{$var}{'Type'} ) {
                        my $ftype = $vars{$var}{'Type'};
                        my $vtype = toCType($ftype);
                        $chunk =~ s/F2C\-ACC\:\ Type\ not\ recognized\./$vtype/;
                    } else {
                        croak "No entry for $var in $sub\n" . Dumper(%vars);
                    }
                  };
            }
            $line = join( ',', @chunks );
        };

        $line =~ /F2C\-ACC\:\ xUnOp\ not\ supported\./
          && do {    # FIXME: we assume the unitary operation is .not.
            my @chunks = split( /\,/, $line );
            for my $chunk (@chunks) {
                $chunk =~ s/F2C\-ACC\:\ xUnOp\ not\ supported\./\!/;
            }
            $line = join( ',', @chunks );

          };
          # Can't have externs!
        next if $line =~ /^\s*extern\s+void\s+noop/;
        
        if ( $skip == 0 ) {
            if ( $line =~ /^\s*extern\s+\w+\s+(\w+)_\(/ ) {
                my $inc   = $1;
                my $hfile = $inc . '.h';

                if ( not -e $hfile ) {
                    $line =~ s/^\s*extern\s+//;
                }
                print $PPCSRC '#include "' . $hfile . '"' . "\n";
                next;
            }

            $line =~ /^\s+extern\s+\w+\s+\w+[;,]/ && do {
                $line =~ s|^|\/\/|;
            };    # because parameters are macros, not variables

            #*  float float and similar need to be removed
            $line =~ /float\s+(float|sngl|sqrt)/ && do {
                $line =~ s|^|\/\/|;
            };

            $line =~ /int\s+(int|mod)/ && do {
                $line =~ s|^|\/\/|;
            };

            $line =~ /(short|int)\s+(int2|short)/ && do {
                $line =~ s|^|\/\/|;
            };

            $line =~ /(long|int)\s+(int8|long)/ && do {
                $line =~ s|^|\/\/|;
            };
            if ( $line =~ /^\s*(?:\w+\s+)?\w+\s+(\w+);/ )
            { # FIXME: only works for types consisting of single strings, e.g. double precision will NOT match!
                my $mf = $1;
                if (
                    exists $stref->{'Subroutines'}{$sub}{'CalledSubs'}{'Set'}
                    {$mf} )
                {
                    $line =~ s|^|\/\/|;
                }
            }
            $line =~ s/int\(/(int)(/g
              ;    # int is a FORTRAN primitive converting float to int
            $line =~ s/(int2|short)\(/(int)(/g
              ;    # int is a FORTRAN primitive converting float to int
            $line =~ s/(int8|long)\(/(long)(/g
              ;    # int is a FORTRAN primitive converting float to int
            $line =~ s/float\(/(float)(/g
              ;    # float is a FORTRAN primitive converting int to float
            $line =~ s/(dfloat|dble)\(/(double)(/g
              ;    # dble is a FORTRAN primitive converting int to float
            $line =~ s/sngl\(/(/g
              ;    # sngl is a FORTRAN primitive converting double to float

            $line =~ /goto\ C__(\d+):/ && do {
                my $label = $1;
                if ( $isBreak->($label) ) {
                    $_ = $line;
                    eval("s/goto\\ C__$label:/break/");
                    $line = $_;
                } else {
                    $line =~ s/C__(\d+)\:/C__$1/;
                }
            };

     #    s/goto\ C__37:/break/; # must have a list of all gotos that are breaks
            $line =~ /^\s+C__(\d+)/ && do {
                my $label = $1;
                if ( $isNoop->($label) ) {
                    $line =~ s|^|\/\/|;
                }
            };

            # Subroutine call
            $line !~ /\#define/
              && $line =~ s/\s([\+\-\*\/\%])\s/$1/g;    # FIXME: super ad-hoc!
            $line =~ /(^|^.*?\{\s)\s*(\w+)_\(\s([\+\*\,\w\(\)\[\]]+)\s\);/
              && do {

                # We need to replace the arguments with the correct ones.
                my $maybe_if  = $1;
                my $calledsub = $2;
                my $argstr    = $3;
                my @args      = split( /\s*\,\s*/, $argstr )
                  ; # FIXME: this will split things like v1,indzindicator[FTNREF1D(i,1)],v3
                
                my $called_sub_args =
                  $stref->{'Subroutines'}{$calledsub}{'RefactoredArgs'}{'List'};
                my @nargs = ();

                for my $ii ( 0 .. scalar @{$called_sub_args} - 1 ) {
                    my $arg            = shift @args;
                    my $called_sub_arg = $called_sub_args->[$ii];
                    $ii++;
                    my $is_input_scalar =
                      ( $stref->{'Subroutines'}{$calledsub}{'Vars'}
                          {$called_sub_arg}{'ArrayOrScalar'} eq 'Scalar' )
                      && ( $stref->{'Subroutines'}{$calledsub}{'RefactoredArgs'}
                        {$called_sub_arg}{'IODir'} eq 'In' )
                      ? 1
                      : 0;

                    if ( $arg =~ /^\((\w+)\)$/ ) {
                        $arg = $1;
                    }

                    #               $targ=~s/[\(\)]//g;
                    if ( $arg =~ /(\w+)\[/ ) {
                        my $var = $1;

                        # What is the type of $var?
                        my %calledsubvars =
                          %{ $stref->{'Subroutines'}{$calledsub}{'Vars'} };
                        my $ftype  = $calledsubvars{$called_sub_arg}{'Type'};
                        my $tftype = $vars{$var}{'Type'};
                        if ( $ftype ne $tftype ) {
                            print
"WARNING: $tftype $var ($sub) <> $ftype $called_sub_arg ($calledsub)\n"
                              if $W;
                        }
                        my $ctype  = toCType($ftype);
                        my $cptype = $ctype . '*';

                        while ( $arg !~ /\]/ ) {
                            my $targ = shift @args;

                            #                    print "TARG: $targ\t";
                            $arg .= ',' . $targ;

                            #                    print $arg,"\n";
                        }

                        if ( not $is_input_scalar ) {
                            $arg =~ s/\[/+/g;
                            $arg =~ s/\]//g;
                            $arg = "($cptype)($arg)";
                        }

                        #               die $arg;
                    }

                    #               print $arg,"\n";
                    if ( exists $argvars{ $arg . '__G' } ) {

# this is an argument variable
# if the called function argument type is Input Scalar
# and the argument variable is in %input_scalars
# then don't add __G
# Still not good: the arg for the called sub must be positional! So we must get the signature and count the position ...
# which means we need to parse the source first.

# print " SUBCALL $calledsub: $called_sub_arg: $is_input_scalar:" . $stref->{'Subroutines'}{$calledsub}{'Vars'}{$called_sub_arg}{'ArrayOrScalar'} .','. $stref->{'Subroutines'}{$calledsub}{'RefactoredArgs'}{'IODir'}{$called_sub_arg}."\n";

                        if ( not exists $input_scalars{ $arg . '__G' } ) {

                            # means v__G in enclosing sub signature is a pointer
                            if ( not $is_input_scalar ) {

                                # means the arg of the called sub is a pointer
                                $arg .= '__G';
                            } else {

                                # means the arg of the called sub is a scalar
                                #                           $arg;
                            }
                        } else {

                            # means v in enclosing sub signature is a scalar
                            if ( not $is_input_scalar ) {
                                $arg = '&' . $arg;
                            }
                        }
                    } elsif ( exists $vars{$arg}
                        and $vars{$arg}{'ArrayOrScalar'} ne 'Array' )
                    {

                        # means $arg is a Scalar
                        if ( not $is_input_scalar ) {
                            $arg = '&' . $arg;
                        }
                    }
                    push @nargs, $arg;
                }
                my $nargstr = join( ',', @nargs );
                chomp $line;
                $line =~ /^\s+if/ && do {
                    $line =~ s/^.*?\{//;
                };
                $line =~ s/\(.*//;
                $line .= '(' . $nargstr . ');' . "\n";
                my $close_if = ( $maybe_if =~ /if\s*\(/ ) ? '}' : '';
                $line = $maybe_if . $line . $close_if;

                #           die $line if $calledsub=~/initialize/;
              };

        } else {
            $skip = 0;
        }

        # VERY AD-HOC: get rid of write() statements
        $line =~ /^\s*write\(/ && do {
            $line =~ s|^|\/\/|;
        };

# fix % on float
# This is a pain: need to get the types of the operands and figure out the cases:
# int float, float int, float float
# FIXME: we assume float, float
        $line =~ s/\s+([\w\(\)]+)\s*\%\s*([\w\(\)]+)/ mod($1,$2)/;
        
        print $PPCSRC $line unless $skipline;
    }
    close $CSRC;
    close $PPCSRC;
}    # END of postprocess_C()

# -----------------------------------------------------------------------------
sub toCType {
    ( my $ftype, my $kind ) = @_;
    
    if (not defined $kind) {$kind=4};
    my %corr = (
        'logical'          => 'int', # C has no bool
        'integer'          => ($kind == 8 ? 'long' : 'int'),
        'real'             => ($kind == 8 ? 'double' : 'float'),
        'double precision' => 'double',
        'doubleprecision'  => 'double',
        'character'        => 'char'
    );
    if ( exists( $corr{$ftype} ) ) {
        return $corr{$ftype};
    } else {
        print "WARNING: NO TYPE for $ftype\n" if $W;
        return 'NOTYPE';
    }
}    # END of toCType()
# -----------------------------------------------------------------------------
sub add_to_C_build_sources {
    ( my $f, my $stref ) = @_;
    my $sub_or_func = sub_func_incl_mod( $f, $stref );
    my $is_inc = $sub_or_func eq 'IncludeFiles';
    if (not $is_inc ) {
    my $src =  $stref->{$sub_or_func}{$f}{'Source'};        
    if ( not exists $stref->{'BuildSources'}{'C'}{$src} ) {
        print "ADDING $src to C BuildSources\n" if $V;
        $stref->{'BuildSources'}{'C'}{$src} = 1;
#        $stref->{$sub_or_func}{$f}{'Status'} = $C_SOURCE;
    }
    } else {
    	my $inc=$f;
        if ( not exists $stref->{'BuildSources'}{'H'}{$inc} ) {
            print "ADDING $inc to C Header BuildSources\n" if $V;
            $stref->{'BuildSources'}{'H'}{$inc} = 1;
        }
    	
    }

#    for my $inc ( keys %{ $stref->{$sub_or_func}{$f}{'Includes'} } ) {
#        if ( not exists $stref->{'BuildSources'}{'H'}{$inc} ) {
#            print "ADDING $inc to C Header BuildSources\n" if $V;
#            $stref->{'BuildSources'}{'H'}{$inc} = 1;
#        }
#    }
    return $stref;
} # END of add_to_C_build_sources()
