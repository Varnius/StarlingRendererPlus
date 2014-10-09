package starling.extensions.post.effects
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Program3D;
	
	import starling.core.Starling;
	import starling.extensions.deferredShading.RenderPass;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;

	/**
	 * Provides blur and blurWide methods.
	 */
	public class BlurBase extends PostEffect
	{
		private static const BLUR:String = 'PostEffectBlur';
		private static const WIDE_BLUR:String = 'PostEffectBlurWide';
		protected var blurProgram:Program3D;
		protected var wideBlurProgram:Program3D;
		
		// Convolution kernel values for blur shader
		protected var kernelValues:Vector.<Number> = new <Number>[
			0.09, 0.11, 0.18, 0.24, 0.18, 0.11, 0.09, 0
		];
		
		// Texture offsets for blur shader
		protected var textureOffsets:Vector.<Number> = new <Number>[
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		
		// Convolution kernel values for blur shader
		protected var kernelValuesWide:Vector.<Number> = new <Number>[
			0.03, 0.06, 0.11, 0.18, 0.24, 0.18, 0.11, 0.06, 0.03, 0, 0, 0
		];
		
		protected var hOffset:Number;
		protected var vOffset:Number;
		protected var blurClearParamsHorizontal:Vector.<Number> = new <Number>[0, 0, 0, 1];
		protected var blurClearParamsVertical:Vector.<Number> = new <Number>[0, 0, 0, 1];
		protected var blurBlendFactors:Vector.<String> = new <String>[
			Context3DBlendFactor.ONE,
			Context3DBlendFactor.ZERO,
			Context3DBlendFactor.ONE,
			Context3DBlendFactor.ZERO
		];
		
		/**
		 * Horizontal blur amount
		 */
		public var blurX:Number = 1.0;
		
		/**
		 * Vertical blur amount
		 */
		public var blurY:Number = 1.0;
		
		override public function dispose(programs:Boolean = false):void
		{
			super.dispose(programs);
			
			if(programs) Starling.current.deleteProgram(BLUR);
			if(programs) Starling.current.deleteProgram(WIDE_BLUR);
		}
		
		override protected function prepare():void
		{		
			super.prepare();
			
			if(!Starling.current.getProgram(BLUR))
			{
				blurProgram = Starling.current.registerProgramFromSource(BLUR, BLUR_VERTEX_SHADER, BLUR_FRAGMENT_SHADER);
			}
			else
			{
				blurProgram = Starling.current.getProgram(BLUR);
			}
			
			if(!Starling.current.getProgram(WIDE_BLUR))
			{
				wideBlurProgram = ShaderUtils.registerProgram(WIDE_BLUR, WIDE_BLUR_VERTEX_SHADER, WIDE_BLUR_FRAGMENT_SHADER, 2);
				
			}
			else
			{
				wideBlurProgram = Starling.current.getProgram(WIDE_BLUR);
			}
		}
		
		/*---------------------------
		Blur
		---------------------------*/
		
		/**
		 * Uses two render targets to apply blur to source texture.
		 * The blur is rendered like this: source -> destination, destination -> source.
		 * Should work with BASELINE+ modes.
		 */
		protected function blur(source:Texture, destination:Texture, blurAlongX:Boolean = true, blurAlongY:Boolean = true):void
		{
			var context:Context3D = Starling.current.context;
			var targetWidth:Number = source.nativeWidth;
			var targetHeight:Number = source.nativeHeight;
			
			hOffset = 1 / targetWidth;
			vOffset = 1 / targetHeight;
			
			/*-------------------
			Horizontal blur pass
			-------------------*/			
			
			if(blurAlongX)
			{				
				textureOffsets[0]  = -3 * hOffset * blurX;
				textureOffsets[4]  = -2 * hOffset * blurX;
				textureOffsets[8]  =     -hOffset * blurX;
				textureOffsets[12] =  0;
				textureOffsets[16] =      hOffset * blurX;
				textureOffsets[20] =  2 * hOffset * blurX;
				textureOffsets[24] =  3 * hOffset * blurX;		
				
				// Set attributes
				context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);				
				
				// Set constants 
				context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, textureOffsets, 8);
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, kernelValues, 2);
				
				// Set samplers
				context.setTextureAt(0, source.base);
				
				// Set program
				context.setProgram(blurProgram);
				
				// Render blur
				context.setRenderToTexture(destination.base);
				context.setBlendFactors(blurBlendFactors[0], blurBlendFactors[1]);
				context.clear(
					blurClearParamsHorizontal[0],
					blurClearParamsHorizontal[1],
					blurClearParamsHorizontal[2],
					blurClearParamsHorizontal[3]
				);
				
				context.drawTriangles(renderer.overlayIndexBuffer);
				context.setRenderToBackBuffer();
				
				// Reset texture offsets
				textureOffsets[0]  = 0;
				textureOffsets[4]  = 0;
				textureOffsets[8]  = 0;
				textureOffsets[12] = 0;
				textureOffsets[16] = 0;
				textureOffsets[20] = 0;
				textureOffsets[24] = 0;
			}			
			
			/*-------------------
			Vertical blur pass
			-------------------*/
			
			if(blurAlongY)
			{
				textureOffsets[1]  = -3 * vOffset * blurY;
				textureOffsets[5]  = -2 * vOffset * blurY;
				textureOffsets[9]  =     -vOffset * blurY;
				textureOffsets[13] =  0;
				textureOffsets[17] =      vOffset * blurY;
				textureOffsets[21] =  2 * vOffset * blurY;
				textureOffsets[25] =  3 * vOffset * blurY;
				
				// Set attributes
				context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
				
				// Set constants 
				context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, textureOffsets, 8);
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, kernelValues, 2);
				
				// Set samplers
				context.setTextureAt(0, destination.base);
				
				// Set program
				context.setProgram(blurProgram);
				
				// Render intermediate convolution result
				context.setRenderToTexture(source.base);
				context.setBlendFactors(blurBlendFactors[2], blurBlendFactors[3]);
				context.clear(
					blurClearParamsVertical[0],
					blurClearParamsVertical[1],
					blurClearParamsVertical[2],
					blurClearParamsVertical[3]
				);
				
				context.drawTriangles(renderer.overlayIndexBuffer);			
				context.setRenderToBackBuffer();
				
				textureOffsets[1] = 0;
				textureOffsets[5] = 0;
				textureOffsets[9] = 0;
				textureOffsets[13] = 0;
				textureOffsets[17] = 0;
				textureOffsets[21] = 0;
				textureOffsets[25] = 0;
			}		
		}
		
		/**
		 * Uses two render targets to apply wide blur (large kernel) to source texture.
		 * The blur is rendered like this: source -> destination, destination -> source.
		 * Should work with STANDARD+ modes. (currently this blur is only 2 samples bigger than regular one, as only 10 varyings are allowed)
		 * todo: more samples, it's possible now...
		 */
		protected function blurWide(source:Texture, destination:Texture, blurAlongX:Boolean = true, blurAlongY:Boolean = true):void
		{
			var context:Context3D = Starling.current.context;
			var targetWidth:Number = source.nativeWidth;
			var targetHeight:Number = source.nativeHeight;
			
			hOffset = 1 / targetWidth;
			vOffset = 1 / targetHeight;
			
			/*-------------------
			Horizontal blur pass
			-------------------*/			
			
			if(blurAlongX)
			{
				textureOffsets[0]  = -4 * hOffset * blurX;			
				textureOffsets[4] = -3 * hOffset * blurX;
				textureOffsets[8] = -2 * hOffset * blurX;
				textureOffsets[12] =     -hOffset * blurX;
				textureOffsets[16] =  0;
				textureOffsets[20] =      hOffset * blurX;
				textureOffsets[24] =  2 * hOffset * blurX;
				textureOffsets[28] =  3 * hOffset * blurX;			
				textureOffsets[32] =  4 * hOffset * blurX;	
				
				// Set attributes
				context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);				
				
				// Set constants 
				context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, textureOffsets, 9);
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, kernelValuesWide, 3);
				
				// Set samplers
				context.setTextureAt(0, source.base);
				
				// Set program
				context.setProgram(wideBlurProgram);
				
				// Render blur
				context.setRenderToTexture(destination.base);
				context.setBlendFactors(blurBlendFactors[0], blurBlendFactors[1]);
				context.clear(
					blurClearParamsHorizontal[0],
					blurClearParamsHorizontal[1],
					blurClearParamsHorizontal[2],
					blurClearParamsHorizontal[3]
				);
				
				context.drawTriangles(renderer.overlayIndexBuffer);			
				context.setRenderToBackBuffer();
				
				// Reset texture offsets
				textureOffsets[0] = 0;
				textureOffsets[4] = 0;
				textureOffsets[8] = 0;
				textureOffsets[12] = 0;
				textureOffsets[16] = 0;
				textureOffsets[20] = 0;
				textureOffsets[24] = 0;
				textureOffsets[28] = 0;	
				textureOffsets[32] = 0;
			}
			
			/*-------------------
			Vertical blur pass
			-------------------*/
			
			if(blurAlongY)
			{
				textureOffsets[1] = -4 * vOffset * blurY;			
				textureOffsets[5] = -3 * vOffset * blurY;
				textureOffsets[9] = -2 * vOffset * blurY;
				textureOffsets[13] =     -vOffset * blurY;
				textureOffsets[17] =  0;
				textureOffsets[21] =      vOffset * blurY;
				textureOffsets[25] =  2 * vOffset * blurY;
				textureOffsets[29] =  3 * vOffset * blurY;			
				textureOffsets[33] =  4 * vOffset * blurY;
				
				// Set attributes
				context.setVertexBufferAt(0, renderer.overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(1, renderer.overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
				
				// Set constants 
				context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, textureOffsets, 9);
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, kernelValuesWide, 3);
				
				// Set samplers
				context.setTextureAt(0, destination.base);
				
				// Set program
				context.setProgram(wideBlurProgram);
				
				// Render intermediate convolution result
				context.setRenderToTexture(source.base);
				context.setBlendFactors(blurBlendFactors[2], blurBlendFactors[3]);
				context.clear(
					blurClearParamsVertical[0],
					blurClearParamsVertical[1],
					blurClearParamsVertical[2],
					blurClearParamsVertical[3]
				);
				
				context.drawTriangles(renderer.overlayIndexBuffer);			
				context.setRenderToBackBuffer();
				
				textureOffsets[1] = 0;
				textureOffsets[5] = 0;
				textureOffsets[9] = 0;
				textureOffsets[13] = 0;
				textureOffsets[17] = 0;
				textureOffsets[21] = 0;
				textureOffsets[25] = 0;
				textureOffsets[29] = 0;
				textureOffsets[33] = 0;
			}
		}
		
		/*---------------------------
		Blur
		---------------------------*/		
		
		protected const BLUR_VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Add texture offsets, move to varyings
					"add v0, va1, vc0",
					"add v1, va1, vc1",
					"add v2, va1, vc2",
					"add v3, va1, vc3",
					"add v4, va1, vc4",
					"add v5, va1, vc5",
					"add v6, va1, vc6",
					
					// Set vertex position as output
					"mov op, va0"		
				]
			);
		
		protected const BLUR_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[					
					// Apply convolution kernel
					
					"tex ft0, v0,  fs0 <2d,clamp,linear>",
					"tex ft1, v1,  fs0 <2d,clamp,linear>",
					"mul ft0, ft0, fc0.x",
					"mul ft1, ft1, fc0.y",
					"add ft0, ft0, ft1",
					
					"tex ft1, v2,  fs0 <2d,clamp,linear>",
					"tex ft2, v3,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc0.z",
					"mul ft2, ft2, fc0.w",
					"add ft0, ft0, ft1",
					"add ft0, ft0, ft2",
					
					"tex ft1, v4,  fs0 <2d,clamp,linear>",
					"tex ft2, v5,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc1.x",
					"mul ft2, ft2, fc1.y",
					"add ft0, ft0, ft1",
					"add ft0, ft0, ft2",
					
					"tex ft1, v6,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc1.z",
					"add ft0, ft0, ft1",
					
					"mov oc, ft0",
				]
			);
		
		/*---------------------------
		Wide blur
		---------------------------*/		
		
		protected const WIDE_BLUR_VERTEX_SHADER:String = 			
			ShaderUtils.joinProgramArray(
				[					
					// Add texture offsets, move to varyings
					"add v0, va1, vc0",
					"add v1, va1, vc1",
					"add v2, va1, vc2",
					"add v3, va1, vc3",
					"add v4, va1, vc4",
					"add v5, va1, vc5",
					"add v6, va1, vc6",					
					"add v7, va1, vc7",
					"add v8, va1, vc8",
					
					// Set vertex position as output
					"mov op, va0"		
				]
			);
		
		protected const WIDE_BLUR_FRAGMENT_SHADER:String =
			ShaderUtils.joinProgramArray(
				[					
					// Apply convolution kernel
					
					"tex ft0, v0,  fs0 <2d,clamp,linear>",
					"tex ft1, v1,  fs0 <2d,clamp,linear>",
					"mul ft0, ft0, fc0.x",
					"mul ft1, ft1, fc0.y",
					"add ft0, ft0, ft1",
					
					"tex ft1, v2,  fs0 <2d,clamp,linear>",
					"tex ft2, v3,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc0.z",
					"mul ft2, ft2, fc0.w",
					"add ft0, ft0, ft1",
					"add ft0, ft0, ft2",
					
					"tex ft1, v4,  fs0 <2d,clamp,linear>",
					"tex ft2, v5,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc1.x",
					"mul ft2, ft2, fc1.y",
					"add ft0, ft0, ft1",
					"add ft0, ft0, ft2",
					
					"tex ft1, v6,  fs0 <2d,clamp,linear>",
					"tex ft2, v7,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc1.z",
					"mul ft2, ft2, fc1.w",
					"add ft0, ft0, ft1",
					"add ft0, ft0, ft2",
					
					"tex ft1, v8,  fs0 <2d,clamp,linear>",
					"mul ft1, ft1, fc2.x",
					"add ft0, ft0, ft1",
					
					"mov oc, ft0",
				]
			);
	}
}