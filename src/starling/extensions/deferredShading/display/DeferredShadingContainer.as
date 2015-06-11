package starling.extensions.deferredShading.display
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.extensions.deferredShading.RenderPass;
	import starling.extensions.deferredShading.renderer_internal;
	import starling.extensions.deferredShading.interfaces.IAreaLight;
	import starling.extensions.deferredShading.interfaces.IShadowMappedLight;
	import starling.extensions.deferredShading.lights.AmbientLight;
	import starling.extensions.deferredShading.lights.Light;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;
	import starling.utils.Color;
	
	use namespace renderer_internal;
	
	/**
	 * DeferredRenderer. Serves as a container for all other display objects
	 * that should have lighting applied to them.
	 */
	public class DeferredShadingContainer extends Sprite
	{		
		private static const AMBIENT_PROGRAM:String = 'AmbientProgram';
		
		protected var assembler:AGALMiniAssembler = new AGALMiniAssembler();
		
		private static const DEFAULT_AMBIENT:AmbientLight = new AmbientLight(0x000000)
		public static var defaultNormalMap:Texture;
		public static var defaultDepthMap:Texture;		
		public static var defaultSpecularMap:Texture;
		
		public static var OPCODE_LIMIT:int;
		public static var AGAL_VERSION:int;
		
		// Quad
		
		protected var overlayVertexBuffer:VertexBuffer3D;
		protected var overlayIndexBuffer:IndexBuffer3D;
		protected var vertices:Vector.<Number> = new <Number>[-1, 1, 0, 0, 0, -1, -1, 0, 0, 1, 1,  1, 0, 1, 0, 1, -1, 0, 1, 1];
		protected var indices:Vector.<uint> = new <uint>[0,1,2,2,1,3];
		
		// Program constants
		
		private var ambient:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 1.0];
		
		public static var renderPass:String = RenderPass.NORMAL;
		
		// Render targets	
		
		private var MRTPassRenderTargets:Vector.<Texture>;
		public var diffuseRT:Texture;
		public var normalsRT:Texture;
		public var depthRT:Texture;
		
		// Render targets for shadows
		
		public var occludersRT:Texture;
		
		// Lights
		
		private var tmpRenderTargets:Vector.<Texture> = new Vector.<Texture>();
		private var lights:Vector.<Light> = new Vector.<Light>();
		private var stageBounds:Rectangle = new Rectangle();
		private var tmpBounds:Rectangle = new Rectangle();
		private var visibleLights:Vector.<Light> = new Vector.<Light>
		private var obs:Vector.<DisplayObject> = new Vector.<DisplayObject>();
		
		// Shadows
		
		private var occluders:Vector.<DisplayObject> = new Vector.<DisplayObject>();
		private var shadowMapRect:Rectangle = new Rectangle();		
		
		// Misc		
		
		private var prepared:Boolean = false;
		private var prevRenderTargets:Vector.<Texture> = new Vector.<Texture>();
		
		/**
		 * Class constructor. Creates a new instance of DeferredShadingContainer.
		 */
		public function DeferredShadingContainer()
		{
			if(Starling.current.profile == 'standard')
			{
				OPCODE_LIMIT = 1024;
				AGAL_VERSION = 2;
			}
			else if(Starling.current.profile == 'standardExtended') 
			{
				OPCODE_LIMIT = 2048;
				AGAL_VERSION = 3;
			}
			else
				trace('[StarlingRendererPlus] Current Stage3D profile is not supported by RendererPlus.');
			
			prepare();
			registerPrograms();
			
			// Handle lost context			
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
		
		/*---------------------------
		Public methods
		---------------------------*/
		
		override public function addChildAt(child:DisplayObject, index:int):DisplayObject
		{
			if(child is Light)
			{
				lights.push(child as Light);
			}
			
			return super.addChildAt(child, index);
		}
		
		override public function removeChildAt(index:int, dispose:Boolean=false):DisplayObject
		{
			if(index >= 0 && index < numChildren)
			{
				var child:DisplayObject = getChildAt(index);
			}
			
			if(child is Light)
			{
				lights.splice(lights.indexOf(child as Light), 1);
			}
			
			return super.removeChildAt(index, dispose);
		}
		
		/**
		 * Adds occluder. Only occluders added this way will cast shadows.
		 */
		public function addOccluder(occluder:DisplayObject):void
		{
			occluders.push(occluder);
		}
		
		/**
		 * Removes occluder, so it won`t cast shadows anymore.
		 */
		public function removeOccluder(occluder:DisplayObject):void
		{
			occluders.splice(occluders.indexOf(occluder), 1);
		}
		
		public override function dispose():void
		{
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			diffuseRT.dispose();
			normalsRT.dispose();
			depthRT.dispose();
			occludersRT.dispose();
			
			overlayVertexBuffer.dispose();
			overlayIndexBuffer.dispose();
			
			super.dispose();
		}
		
		/*---------------------------
		Overrides
		---------------------------*/
		
		private function prepare():void
		{
			var context:Context3D = Starling.context;
			var w:Number = Starling.current.nativeStage.stageWidth;
			var h:Number = Starling.current.nativeStage.stageHeight;			
			
			// Create a quad for rendering full screen passes
			
			overlayVertexBuffer = context.createVertexBuffer(4, 5);
			overlayVertexBuffer.uploadFromVector(vertices, 0, 4);
			overlayIndexBuffer = context.createIndexBuffer(6);
			overlayIndexBuffer.uploadFromVector(indices, 0, 6);
			
			// Create render targets 
			// HALF_FLOAT format is used to increase the precision of specular params
			// No difference for normals or depth because those aren`t calculated at the run time but all RTs must be same format
			
			diffuseRT = Texture.empty(w, h, false, false, true, -1, Context3DTextureFormat.RGBA_HALF_FLOAT);
			normalsRT = Texture.empty(w, h, false, false, true, -1, Context3DTextureFormat.RGBA_HALF_FLOAT);
			depthRT = Texture.empty(w, h, false, false, true, -1, Context3DTextureFormat.RGBA_HALF_FLOAT);
			occludersRT = Texture.empty(w, h, false, false, true, -1, Context3DTextureFormat.BGRA);
			
			MRTPassRenderTargets = new Vector.<Texture>();
			MRTPassRenderTargets.push(diffuseRT, normalsRT, depthRT);
			
			// Default maps
			
			// Normal
			
			var bd:BitmapData = new BitmapData(4, 4);
			bd.fillRect(new Rectangle(0, 0, 4, 4), 0xFF8080FF);
			defaultNormalMap = Texture.fromBitmapData(bd, false);
			
			// Specular
			
			bd.fillRect(new Rectangle(0, 0, 4, 4), 0xFFFFFFFF);
			defaultSpecularMap = Texture.fromBitmapData(bd, false);
			
			// Depth
			
			bd.fillRect(new Rectangle(0, 0, 4, 4), 0xFF000000);
			defaultDepthMap = Texture.fromBitmapData(bd, false);
			
			prepared = true;
		}
		
		private function registerPrograms():void
		{
			var target:Starling = Starling.current;
			
			if(target.hasProgram(AMBIENT_PROGRAM))
			{
				return;
			}
			
			var vertexProgramCode:String = 
				ShaderUtils.joinProgramArray(
					[
						'mov op, va0',
						'mov v0, va1'
					]
				);		
			
			// fc0 - ambient color [r, g, b, 1.0]
			
			var fragmentProgramCode:String =
				ShaderUtils.joinProgramArray(
					[						
						'tex ft1, v0.xy, fs4 <2d, clamp, linear, mipnone>',
						'mov ft1.w, fc0.w',
						'mul oc, ft1, fc0',
					]
				);
			
			var vertexProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, 1);
			
			var fragmentProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode, 1);
			
			target.registerProgram(AMBIENT_PROGRAM, vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
		}
		
		
		override public function render(support:RenderSupport, parentAlpha:Number):void
		{
			var obj:DisplayObject;
			
			if(!prepared)
			{
				prepare();
			}			
			
			if(!lights.length)
			{
				return;
			}
			
			// Find visible lights and ambient light
			
			visibleLights.length = 0;
			var ambientLight:AmbientLight;
			stageBounds.setTo(0, 0, stage.stageWidth, stage.stageHeight);
			
			for each(var l:Light in lights)
			{				
				// If there are multiple ambient lights - use the last one added
				
				if(l is AmbientLight)
				{
					ambientLight = l as AmbientLight;
					continue;
				}
				
				// Skip early if light is already culled
				// I'm using this with QuadTreeSprite
				
				if(!l.visible || !l.parent)
				{
					continue;
				}
				
				l.getBounds(stage, tmpBounds);				
				
				if(stageBounds.containsRect(tmpBounds) || stageBounds.intersects(tmpBounds))
				{
					visibleLights.push(l);
				}
			}
			
			/*----------------------------------
			MRT pass
			----------------------------------*/
			
			var context:Context3D = Starling.context;
			var isVisible:Boolean;
			
			prevRenderTargets.length = 0;
			prevRenderTargets.push(support.renderTarget, null, null);
			
			// Set render targets, clear them and render background only
			
			support.setRenderTargets(MRTPassRenderTargets);
			
			var prevPass:String = renderPass;
			renderPass = RenderPass.MRT;
			
			support.clear();
			super.render(support, parentAlpha);
			support.finishQuadBatch();			
			
			/*----------------------------------
			Shadows - occluder pass
			----------------------------------*/
			
			// todo: maybe move this to mrt pass??? (as a single channel in depth target)
			// but probably not possible without breaking batching :>
			
			renderPass = RenderPass.OCCLUDERS;
			
			tmpRenderTargets.length = 0;
			tmpRenderTargets.push(occludersRT, null, null);
			
			support.setRenderTargets(tmpRenderTargets);
			support.clear(0xFFFFFF, 1.0);
			
			support.pushMatrix();
			
			for each(var o:DisplayObject in occluders)
			{
				// Skip early if occluder is already culled
				// I'm using this with QuadTreeSprite
				
				if(!o.parent)
				{
					continue;
				}
				
				o.getBounds(stage, tmpBounds);				
				isVisible = stageBounds.containsRect(tmpBounds) || stageBounds.intersects(tmpBounds);
				
				// Render only visible occluders
				
				if(isVisible)
				{					
					support.loadIdentity();
					obj = o;
					
					obs.length = 0;			
					
					// Collect all objects down to the stage, then sum up their transformations bottom up
					
					while(obj != stage)
					{
						obs.push(obj);
						obj = obj.parent;
					}		
					
					for(var j:int = obs.length - 1; j >= 0; j--)
					{
						obj = obs[j];
						support.transformMatrix(obj);
					}
					
					// Tint quads/images black
					// Custom display objects should check if support.renderPass == RenderPass.OCCLUDERS
					// in their render method and render tinted version of an object.
					
					var q:Quad = o as Quad;
					
					if(q)
					{
						q.color = Color.BLACK;
					}
					
					o.render(support, parentAlpha);					
					
					if(q)
					{
						q.color = Color.WHITE;
					}
				}
			}		
			
			support.popMatrix();
			
			/*----------------------------------
			Shadows - shadowmap pass
			----------------------------------*/
			
			renderPass = RenderPass.SHADOWMAP;
			
			for each(l in visibleLights)
			{		
				var shadowMappedLight:IShadowMappedLight = l as IShadowMappedLight;
				
				if(!shadowMappedLight || (shadowMappedLight && !shadowMappedLight.castsShadows))
				{
					continue;
				}			
				
				tmpRenderTargets.length = 0;
				tmpRenderTargets.push(shadowMappedLight.shadowMap, null, null);					
				support.setRenderTargets(tmpRenderTargets, 0, true);
				context.clear(0.0, 0.0, 0.0, 1.0, 1.0);
				context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
				context.setDepthTest(true, Context3DCompareMode.LESS_EQUAL);
				
				shadowMappedLight.renderShadowMap(
					support, 
					occludersRT,
					overlayVertexBuffer,
					overlayIndexBuffer
				);
			}
			
			context.setDepthTest(false, Context3DCompareMode.ALWAYS);	
			
			/*----------------------------------
			Light pass
			----------------------------------*/
			
			support.setRenderTargets(prevRenderTargets);
			
			if(lights.length)
			{				
				renderPass = RenderPass.LIGHTS;		
				
				// Bind textures required by ambient light
				
				context.setTextureAt(4, diffuseRT.base);
				
				// Clear RT with ambient light color
				
				if(!ambientLight)
				{
					ambientLight = DEFAULT_AMBIENT;
				}
				
				support.clear(0x000000, 1.0);
				context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);
				support.pushMatrix();
				
				// Render ambient light as full-screen quad
				
				ambient[0] = ambientLight._colorR;
				ambient[1] = ambientLight._colorG;
				ambient[2] = ambientLight._colorB;
				
				context.setVertexBufferAt(0, overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(1, overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
				context.setProgram(Starling.current.getProgram(AMBIENT_PROGRAM));
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, ambient, 1);			
				context.drawTriangles(overlayIndexBuffer);
				
				context.setVertexBufferAt(1, null);
				
				// Bind textures required by other types lights
				
				context.setTextureAt(0, normalsRT.base);
				context.setTextureAt(1, depthRT.base);
				
				// Render other lights
				
				for each(l in visibleLights)
				{
					var areaLight:IAreaLight = l as IAreaLight;
					shadowMappedLight = l as IShadowMappedLight;
					
					if(areaLight && l.stage)
					{
						if(shadowMappedLight && shadowMappedLight.castsShadows)
						{
							context.setTextureAt(2, shadowMappedLight.shadowMap.base);
							context.setTextureAt(3, occludersRT.base);
						}						
						
						support.loadIdentity();
						
						obj = l;
						obs.length = 0;
						
						while(obj != stage)
						{
							obs.push(obj);
							obj = obj.parent;
						}
						
						for(j = obs.length - 1; j >= 0; j--)
						{
							obj = obs[j];
							support.transformMatrix(obj);
						}			
						
						l.render(support, parentAlpha);
						
						if(shadowMappedLight && shadowMappedLight.castsShadows)
						{
							context.setTextureAt(2, null);
							context.setTextureAt(3, null);
						}
					}
				}
				
				support.popMatrix();
				support.raiseDrawCount();
				
				// Don`t need to set it to null here
				context.setTextureAt(0, null);
				context.setTextureAt(1, null);
				context.setTextureAt(4, null);
			}
			
			renderPass = prevPass;	
		}
		
		/*-----------------------------
		Event handlers
		-----------------------------*/
		
		private function onContextCreated(event:Event):void
		{
			prepared = false;
			prepare();
			registerPrograms();
		}
	}
}