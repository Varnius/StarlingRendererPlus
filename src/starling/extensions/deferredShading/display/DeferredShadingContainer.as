package starling.extensions.deferredShading.display
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DTextureFormat;
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
	import starling.extensions.deferredShading.lights.AmbientLight;
	import starling.extensions.deferredShading.lights.Light;
	import starling.extensions.deferredShading.lights.PointLight;
	import starling.textures.Texture;
	import starling.utils.Color;
	
	use namespace renderer_internal;
	
	/**
	 * DeferredRenderer. Serves as a container for all other display objects
	 * that should have lighting applied to them.
	 */
	public class DeferredShadingContainer extends Sprite
	{		
		protected var assembler:AGALMiniAssembler = new AGALMiniAssembler();
		
		private static const DEFAULT_AMBIENT:AmbientLight = new AmbientLight(0x000000, 1.0)
		public static var defaultNormalMap:Texture;
		public static var defaultDepthMap:Texture;		
		public static var defaultSpecularMap:Texture;
		
		// Quad
		
		protected var overlayVertexBuffer:VertexBuffer3D;
		protected var overlayIndexBuffer:IndexBuffer3D;
		protected var vertices:Vector.<Number> = new <Number>[-1, 1, 0, 0, 0, -1, -1, 0, 0, 1, 1,  1, 0, 1, 0, 1, -1, 0, 1, 1];
		protected var indices:Vector.<uint> = new <uint>[0,1,2,2,1,3];
		
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
			prepare();
			
			// Handle lost context			
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
		
		/*---------------------------
		Public methods
		---------------------------*/
		
		/**
		 * Adds light. Only lights added to the container this way will be rendered.
		 */
		public function addLight(light:Light):void
		{
			lights.push(light);
		}
		
		/**
		 * Removes light, so it won`t be rendered.
		 */
		public function removeLight(light:Light):void
		{
			lights.splice(lights.indexOf(light), 1);
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
					
					// Tint quads/images with black
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
			
			// Max shadow limit is height of shadowmap texture (currently 256)
			
			renderPass = RenderPass.SHADOWMAP;
			
			for each(l in visibleLights)
			{				
				if(!l.castsShadows)
				{
					continue;
				}
				
				var pointLight:PointLight = l as PointLight;
				
				if(pointLight)
				{
					tmpRenderTargets.length = 0;
					tmpRenderTargets.push(pointLight.shadowMap, null, null);					
					support.setRenderTargets(tmpRenderTargets, 0, true);
					context.clear(0.0, 0.0, 0.0, 1.0, 1.0);
					context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
					context.setDepthTest(true, Context3DCompareMode.LESS_EQUAL);
					
					l.renderShadowMap(
						support, 
						occludersRT,
						overlayVertexBuffer,
						overlayIndexBuffer
					);
				}				
			}
			
			context.setDepthTest(false, Context3DCompareMode.ALWAYS);	
			
			/*----------------------------------
			Light pass
			----------------------------------*/
			
			support.setRenderTargets(prevRenderTargets);
			
			if(lights.length)
			{				
				renderPass = RenderPass.LIGHTS;		
				
				// Set previously rendered maps
				
				context.setTextureAt(0, normalsRT.base);
				context.setTextureAt(1, depthRT.base);
				context.setTextureAt(4, diffuseRT.base);
				
				// Clear RT with ambient light color
				
				if(!ambientLight)
				{
					ambientLight = DEFAULT_AMBIENT;
				}
				
				support.clear(ambientLight.color, 1.0);
				context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);
				support.pushMatrix();
				
				for each(l in visibleLights)
				{
					pointLight = l as PointLight;
					
					if(pointLight && pointLight.stage) // todo: check
					{
						if(pointLight.castsShadows)
						{
							context.setTextureAt(2, pointLight.shadowMap.base);
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
						
						if(pointLight.castsShadows)
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
		}
	}
}