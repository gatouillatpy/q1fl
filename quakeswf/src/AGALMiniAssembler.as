package
{
	// todo: conditionals test
	//       indirect indexing
	//       more verbose
	
	import flash.utils.ByteArray;
	import flash.utils.Endian; 

	public class AGALMiniAssembler
	{
		public function AGALMiniAssembler( )
		{			
		}
		
		private function MatchKeyword ( str:String, list:Array, stride:int ) : int 
		{
			var i : int;
			for ( i=0; i<list.length; i+=stride ) {
				var match:int = str.search( list[i] );
				if ( match != -1 ) return i; 				
			}
			return -1;			
		}
		
		public function Assemble ( mode : String, source:String, verbose:Boolean=true ) : ByteArray
		{ 
			agalcode.length = 0;
			error = "";
			var isfrag : Boolean = false; 
			if ( mode=="FRAGMENT" ) isfrag = true
			else if ( mode!="VERTEX" ) {
				error = "error: mode needs to be FRAGMENT or VERTEX but is "+mode+"."; 
			}
			agalcode.endian = Endian.LITTLE_ENDIAN;
			agalcode.writeByte( 0xa0 ); // tag version
			agalcode.writeUnsignedInt( 1 );
			agalcode.writeByte( 0xa1 ); // tag program id
			agalcode.writeByte( isfrag?1:0 ); // vertex or fragment
			
			var lines : Array = source.split("\n");			 		
			var nest : int = 0; 
			var nops : int = 0;
			var i:int; 
			for ( i=0; i<lines.length && error==""; i++ ) {
				var line : String = new String(lines[i]); 
				// remove comments
				var startcomment : int = line.search( "//" );
				if ( startcomment != -1 ) line = line.slice (0,startcomment);
				// grab options
				var optsi : int = line.search(/\[.*\]/g);				
				var opts : Array; 
				if ( optsi != -1 ) { 															
					opts = line.slice(optsi).match( /(\w+)/gi );
					line = line.slice(0,optsi);
				}												
				// find opcode
				var opfound : int = MatchKeyword ( line, opmap, 4 );
				if ( opfound == -1 ) {
					if ( line.length>=3 ) trace ("warning: bad line "+i+": "+lines[i] );
					continue; 	
				}				
				line = line.slice( line.search(opmap[opfound])+opmap[opfound].length ); 
				// nesting check
				if ( opmap[opfound+3] & op_dec_nest ) {
					nest--; 
					if ( nest < 0 ) {
						error = "error: conditional closes without open.";
						break; 
					}
				}
				if ( opmap[opfound+3] & op_inc_nest ) {
					nest++; 
					if ( nest > max_nesting ) {
						error = "error: nesting to deep, maximum allowed is "+max_nesting+".";					
						break; 
					}
				}	
				if ( (opmap[opfound+3] & op_frag_only) && !isfrag ) {
					error = "error: opcode is only allowed in fragment programs.";						
					break;				
				}
			
				if ( verbose ) trace ( "emit opcode="+opmap[opfound] );		
				agalcode.writeUnsignedInt(opmap[opfound+2]);
				nops++;
				if ( nops > max_opcodes ) {
					error = "error: too many opcodes. maximum is "+max_opcodes+".";						
					break;				
				}									
				// get operands, use regexp
				var regs : Array = line.match(/([vof][actps]?)(\d*)?(\.[xyzw]{1,4})?/gi);
				if ( regs.length != opmap[opfound+1] ) {
					error = "error: wrong number of operands. found "+regs.length+" but expected "+opmap[opfound+1]+".";						
					break; 					
				}
				var badreg : Boolean = false; 
				var pad : uint = 64+64+32; 
				for ( var j:int=0; j<regs.length; j++ ) {
					var regfound : int = MatchKeyword ( regs[j], regmap, 5 );
					if ( regfound == -1 ) {
						error = "error: could not parse operand "+j+" ("+regs[j]+").";	
						badreg = true; 
						break; 
					}
					if ( !(regmap[regfound+4] & reg_vert) && !isfrag ) {
						error = "error: register operand "+j+" ("+regs[j]+") only allowed in fragment programs.";	
						badreg = true; 
						break;					
					} 
					if ( !(regmap[regfound+4] & reg_frag) && isfrag ) {
						error = "error: register operand "+j+" ("+regs[j]+") only allowed in vertex programs.";	
						badreg = true; 
						break;					
					} 											
					regs[j] =  regs[j].slice(  regs[j].search(regmap[regfound])+regmap[regfound].length );
					var idxmatch : Array = regs[j].match( /\d+/ );
					var regidx : uint = 0; 									
					if ( idxmatch ) regidx = uint(idxmatch[0]);					
					if ( regmap[regfound+3] < regidx ) {
						error = "error: register operand "+j+" ("+regs[j]+") index exceeds limit of "+(regmap[regfound+3]+1)+".";	
						badreg = true; 
						break;								
					}
					var regmask : uint;  
					var maskmatch : Array = regs[j].match ( /(\.[xyzw]{1,4})/ );	
					var isdest : Boolean =  ( j==0 && !(opmap[opfound+3]&op_nodest) );
					var issampler : Boolean = (j==2 && (opmap[opfound+3]&op_special_tex) );
					if ( maskmatch ) {
						regmask = 0;
						var cv : uint; 
						for ( var k:int = 1; k<maskmatch[0].length; k++ ) {
							cv = maskmatch[0].charCodeAt(k) - "x".charCodeAt(0);
							if ( cv > 2 ) cv=3; 							
							if ( isdest ) regmask |= 1<<cv;
							else regmask |= cv<<((k-1)<<1);
						}
						if ( !isdest ) for ( ; k<=4; k++ ) regmask |= cv<<((k-1)<<1) // repeat last								
					} else {
						regmask = isdest?0xf:0xe4; // id swizzle or mask						
					}
					if ( verbose ) trace ( "  emit argcode="+regmap[regfound]+"["+regidx+"]["+regmask+"]" );					
					if ( isdest ) {						
						agalcode.writeShort( regidx );
						agalcode.writeByte(regmask);
						agalcode.writeByte(regmap[regfound+2]);
						pad -= 32; 
					} else {
						if ( issampler ) {
							trace ( "  emit sampler" );
							var samplerbits : uint = 5; // type 5 
							for ( k = 0; k<opts.length; k++ ) {
								if ( verbose ) trace ( "    opt: "+opts[k] );
								var optfound : int = MatchKeyword ( opts[k], samplermap, 3 );
								if ( optfound==-1 ) {
									trace ( "Warning, unknown sampler option: "+opts[k] );  
								} else {
									if ( samplermap[optfound+1]!=sampler_special_shift ) samplerbits &= ~(0xf<<samplermap[optfound+1]);																
									samplerbits |= uint(samplermap[optfound+2])<<uint(samplermap[optfound+1]);																		
								}								
							}
							agalcode.writeShort(regidx); 		
							agalcode.writeShort(0);				
							agalcode.writeUnsignedInt(samplerbits); 			
							if ( verbose ) trace ( "    bits: "+(samplerbits-5) );  
							pad -= 64;
						} else {
							if ( j==0 ) { agalcode.writeUnsignedInt(0); pad-=32; } 						
							agalcode.writeShort( regidx );
							agalcode.writeByte(0);
							agalcode.writeByte(regmask);
							agalcode.writeByte(regmap[regfound+2]);
							agalcode.writeByte(0);
							agalcode.writeShort(0); 	
							pad -= 64;
						}
					}
				}
				// pad unused regs
				for ( j=0; j<pad; j+=8 ) agalcode.writeByte(0);								
				if ( badreg ) break; 							
			}			
			if ( error != "" ) {
				error += "\n  at line "+i+" "+lines[i]; 
				agalcode.length = 0;
				trace ( error ); 
			}
			return agalcode; 
		}
				
		public var agalcode : ByteArray = new ByteArray(); 
		public var error : String = new String ("");
		
		static private var max_nesting : int = 4;
		static private var max_opcodes : int = 256; 
		
		// regmap flags		
		static private var reg_frag : uint = 0x20;
		static private var reg_vert : uint = 0x40;
		static private var reg_write : uint = 0x1;
		static private var reg_read : uint = 0x2;
		
		// masks and shifts
		static private var sampler_dim_shift : uint = 12;
		static private var sampler_special_shift : uint = 16;
		static private var sampler_repeat_shift : uint = 20;
		static private var sampler_mipmap_shift : uint = 24;
		static private var sampler_filter_shift : uint = 28; 
		
		// options to texture flags (flag, mask) 
		static private var samplermap : Array = new Array (
			"2d", sampler_dim_shift, 0,
			"3d", sampler_dim_shift, 2, 
			"cube", sampler_dim_shift, 1,
			"nearest", sampler_filter_shift, 0,
			"linear", sampler_filter_shift, 1,
			"mipnone", sampler_mipmap_shift, 0,
			"nomip", sampler_mipmap_shift, 0, // alias
			"mipnearest", sampler_mipmap_shift, 1,
			"miplinear", sampler_mipmap_shift, 2, 	
			"centroid", sampler_special_shift, 1<<0, // special are flags
			"repeat", sampler_repeat_shift, 1,
			"wrap", sampler_repeat_shift, 1, // alias
			"clamp", sampler_repeat_shift, 0
			);
		
		// registername, long name, emit code, range(0=non indexed), valid flags
		static private var regmap : Array = new Array (
			"va", "vertex attribute", 	0x0, 7, 	reg_vert | reg_read,
			"vc", "vertex constant", 	0x1, 127, 	reg_vert | reg_read,
			"vt", "vertex temporary", 	0x2, 15, 	reg_vert | reg_write | reg_read,
			"op", "vertex output", 		0x3, 0, 	reg_vert | reg_write, 
			"v", "varying", 			0x4, 7, 	reg_vert | reg_frag  | reg_read  | reg_write,
			"fc", "fragment constant", 	0x1, 15, 	reg_frag | reg_read,
			"ft", "fragment temporary", 0x2, 15, 	reg_frag | reg_write | reg_read,
			"fs", "texture sampler", 	0x5, 7, 	reg_frag | reg_read, 
			"oc", "fragment output", 	0x3, 0, 	reg_frag | reg_write
			);
		
		// opmap flags
		static private var op_scalar : uint = 0x1;
		static private var op_inc_nest : uint = 0x2;
		static private var op_dec_nest : uint = 0x4;
		static private var op_special_tex : uint = 0x8;
		static private var op_special_matrix : uint = 0x10;
		static private var op_frag_only : uint = 0x20;
		static private var op_vert_only : uint = 0x40; 
		static private var op_nodest : uint = 0x80;
		
		// opname, num register arguments, emit code, flags
		static private var opmap : Array = new Array (
			"mov", 2, 0x00, 0,
			"add", 3, 0x01, 0, 
			"sub", 3, 0x02, 0, 
			"mul", 3, 0x03, 0, 
			"div", 3, 0x04, 0,
			"rcp", 2, 0x05, 0,					
			"min", 3, 0x06, 0, 
			"max", 3, 0x07, 0, 
			"frc", 2, 0x08, 0,			
			"sqt", 2, 0x09, 0,
			"rsq", 2, 0x0a, 0,
			"pow", 3, 0x0b, 0,
			"log", 2, 0x0c, 0,
			"exp", 2, 0x0d, 0,
			"nrm", 2, 0x0e, 0,
			"sin", 2, 0x0f, 0,
			"cos", 2, 0x10, 0,
			"crs", 3, 0x11, 0,
			"dp3", 3, 0x12, 0,
			"dp4", 3, 0x13, 0,					
			"abs", 2, 0x14, 0,
			"neg", 2, 0x15, 0,
			"sat", 2, 0x16, 0,
			"m33", 3, 0x17, op_special_matrix, 
			"m44", 3, 0x18, op_special_matrix,
			"m34", 3, 0x19, op_special_matrix,			
			"ifz", 1, 0x1a, op_nodest | op_inc_nest | op_scalar,
			"inz", 1, 0x1b, op_nodest | op_inc_nest | op_scalar,
			"ife", 2, 0x1c, op_nodest | op_inc_nest | op_scalar,
			"ine", 2, 0x1d, op_nodest | op_inc_nest | op_scalar,
			"ifg", 2, 0x1e, op_nodest | op_inc_nest | op_scalar,
			"ifl", 2, 0x1f, op_nodest | op_inc_nest | op_scalar,
			"ieg", 2, 0x20, op_nodest | op_inc_nest | op_scalar,
			"iel", 2, 0x21, op_nodest | op_inc_nest | op_scalar,
			"els", 0, 0x22, op_nodest | op_inc_nest | op_dec_nest,
			"eif", 0, 0x23, op_nodest | op_dec_nest,
			"rep", 1, 0x24, op_nodest | op_inc_nest | op_scalar,
			"erp", 0, 0x25, op_nodest | op_dec_nest,
			"brk", 0, 0x26, op_nodest,
			"kil", 0, 0x27, op_frag_only,
			"tex", 3, 0x28, op_frag_only | op_special_tex		
			);	
	}
}