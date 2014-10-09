package starling.extensions.post.effects
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	
	import starling.core.Starling;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;

	public class Bloom extends BlurBase
	{
		public static const BLOOM:String = 'PostEffectBloom';
		public static const THRESHOLD:String = 'PostEffectBloomThreshold';

		// Cache	

		private var thresholdProgram:Program3D;
		private var bloomProgram:Program3D;
			
		private var a2:Texture;
		private var a4:Texture;
		private var b4:Texture;
		
		private var fc0Params:Vector.<Number> = new <Number>[0, 0, 0, 0];
		private var fc1LuminosityValues:Vector.<Number> = new <Number>[0.2126, 0.7152, 0.0722, 0];
		
		/**
		 * Color threshold.
		 */
		public var threshold:Number = 0.3;
		
		/**
		 * Saturation of bloom.
		 */
		public var bloomSaturation:Number = 1.3;
		
		/**
		 * Blend amount of bloom.
		 */
		public var intensity:Number = 1.0;
		
		public function Bloom()
		{
			_applyType = PostEffect.ADD;
			numDrawCalls = 6;
		}
		
		override public function render():void
		{
			super.render();
			
			var context:Context3D = Starling.current.context;
			
			/*-------------------
			Downscale 
			-------------------*/
			
			resample(input, a2);
			resample(a2, a4);			
			
			/*-------------------
			Render scene with
			color threshold
			-------------------*/
			
			// Set attributes
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);				
			
			fc0Params[0] = threshold;
			fc0Params[3] = 1 - threshold;
			
			// Set constants
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, fc0Params, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, fc1LuminosityValues, 1);
			
			// Set samplers
			context.setTextureAt(0, a4.base);
			
			// Set program
			context.setProgram(thresholdProgram);
			
			// Render
			context.setRenderToTexture(b4.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();
			
			context.drawTriangles(renderer.overlayIndexBuffer);
			
			/*-------------------
			Blur
			-------------------*/
			
			blurWide(b4, a4);
			
			/*-------------------
			Render final view
			-------------------*/
			
			// Set attributes
			context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);			
			
			// Set constants
			fc0Params[1] = intensity;
			fc0Params[3] = bloomSaturation;			
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, fc0Params, 1);
			
			fc0Params[0] = 0.3;
			fc0Params[1] = 0.59;
			fc0Params[2] = 0.11;
			fc0Params[3] = 1.0;
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, fc0Params, 1);
			
			// Set samplers
			context.setTextureAt(0, b4.base);		
			
			// Set program
			context.setProgram(bloomProgram);			
			
			// Combine
			context.setRenderToTexture(a4.base);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.clear();			
			context.drawTriangles(renderer.overlayIndexBuffer);				
			context.setRenderToBackBuffer();
			
			// Clean up
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
			context.setTextureAt(0, null);
			context.setTextureAt(1, null);
			
			output = a4;
		}
		
		override public function dispose(programs:Boolean = false):void
		{
			super.dispose(programs);
			
			if(programs)
			{
				Starling.current.deleteProgram(BLOOM);
				Starling.current.deleteProgram(THRESHOLD);
			}			
			
			if(a2) a2.dispose();
			if(a4) a4.dispose();
			if(b4) b4.dispose();
		}
		
		override protected function prepare():void
		{		
			super.prepare();
			
			var context:Context3D = Starling.current.context;
			
			if(!Starling.current.getProgram(THRESHOLD))
			{
				thresholdProgram = ShaderUtils.registerProgram(THRESHOLD, THRESHOLD_VERTEX_SHADER, THRESHOLD_FRAGMENT_SHADER, 2);
			}
			
			if(!Starling.current.getProgram(BLOOM))
			{
				bloomProgram = ShaderUtils.registerProgram(BLOOM, BLOOM_VERTEX_SHADER, BLOOM_FRAGMENT_SHADER, 1);
			}
			
			dispose();
			
			var sw:int = Starling.current.nativeStage.stageWidth;
			var sh:int = Starling.current.nativeStage.stageHeight;
			
			a2 = Texture.empty(sw / 2, sh / 2, false, false, true, -1, Context3DTextureFormat.BGRA);
			a4 = Texture.empty(sw / 4, sh / 4, false, false, true, -1, Context3DTextureFormat.BGRA);
			b4 = Texture.empty(sw / 4, sh / 4, false, false, true, -1, Context3DTextureFormat.BGRA);
		}
		
		/*---------------------------
		Bloom program
		---------------------------*/		
		
		protected const BLOOM_VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Move UV coords to varying-0
					"mov v0, va1",
					// Set vertex position as output
					"mov op, va0"		
				]
			);
		
		/**
		 * Combines previously rendered maps.
		 */
		protected const BLOOM_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[					
					// Sample regular scene
					//"tex ft0, v0, fs0 <2d,clamp,linear>",			
					// Sample threshold scene
					"tex ft1, v0, fs0 <2d,clamp,linear>",
					
					// Adjust threshold scene color saturation
					"dp3 ft2.xyz, ft1.xyz, fc1.xyz",
					// lerp: x + s * (y - x)
					"sub ft3.xyz, ft1.xyz, ft2.xyz",
					"mul ft3.xyz, ft3.xyz, fc0.www",
					"add ft1.xyz, ft2.xyz, ft3.xyz",
					
					// Adjust color intensity
					"mul ft1.xyz, ft1.xyz, fc0.y",
					
					// 1 - saturate(bloomColor)
					"sat ft2.xyz, ft1.xyz",
					"sub ft2.xyz, fc1.www, ft2.xyz",			
					
					// Return final color
					"mov oc, ft1"
				]
			);
		
		/*---------------------------
		Threshold program
		---------------------------*/
		
		protected const THRESHOLD_VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Move UV coords to varying-0
					"mov v0, va1",
					// Set vertex position as output
					"mov op, va0"		
				]
			);
		
		/**
		 * Combines previously rendered maps.
		 */
		protected const THRESHOLD_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[					
					// Formula: saturate((Color – Threshold) / (1 – Threshold))
					"tex ft0, v0, fs0 <2d,clamp,linear>",
					"sub ft0.xyz, ft0.xyz, fc0.xxx",
					"div ft0.xyz, ft0.xyz, fc0.www",
					"sat ft0, ft0",		
					
					// Return final color
					"mov oc, ft0",
				]
			);
		
		// other formula, works well too but requires conditional
		/*protected const THRESHOLD_FRAGMENT_SHADER:String =
			Utils.joinProgramArray(
				[		
					// Formula: L = (0.2126 * R + 0.7152 * G + 0.0722 * B)
					'tex ft0, v0, fs0 <2d,clamp,linear>',
					'mul ft2.xyz, ft0.xyz, fc1.xyz',
					'add ft1.x, ft2.x, ft2.y',
					'add ft1.x, ft1.x, ft2.z',
					
					'ifl ft1.x, fc0.x',					
						'mov ft0.xyz, fc1.www',					
					'eif',
					
					'mov oc, ft0'
				]
			);*/
	}
}