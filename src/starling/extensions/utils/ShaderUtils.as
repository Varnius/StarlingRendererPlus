package starling.extensions.utils
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Program3D;
	import flash.utils.ByteArray;
	
	import starling.core.Starling;

	public class ShaderUtils
	{
		public static function joinProgramArray(array:Array):String
		{
			return array.join('\n') + '\n';
		}
		
		public static function registerProgram(name:String, vertexProgram:String, fragmentProgram:String, version:int = 1, debug:Boolean = false):Program3D
		{
			var assembler:AGALMiniAssembler = new AGALMiniAssembler(debug);
			var compiledVertex:ByteArray = assembler.assemble(Context3DProgramType.VERTEX, vertexProgram, version);
			var compiledFragment:ByteArray = assembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgram, version);
			
			return Starling.current.registerProgram(name, compiledVertex, compiledFragment);
		}
	}
}