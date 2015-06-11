package starling.extensions.deferredShading.lights
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.extensions.deferredShading.RenderPass;
	import starling.extensions.deferredShading.renderer_internal;
	import starling.extensions.deferredShading.display.DeferredShadingContainer;
	import starling.extensions.deferredShading.interfaces.IAreaLight;
	import starling.extensions.deferredShading.interfaces.IShadowMappedLight;
	import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;
	import starling.utils.VertexData;
	
	use namespace renderer_internal;
	
	/**
	 * Represents an omnidirectional light.
	 */
	public class SpotLight extends Light implements IShadowMappedLight, IAreaLight
	{		
		private static var SPOTLIGHT_PROGRAM:String 				= 'SpotLightProgram';
		private static var SPOTLIGHT_PROGRAM_WITH_SHADOWS:String 	= 'SpotLightProgramWithShadows';
		private static var SHADOWMAP_PROGRAM:String 				= 'SpotLightShadowmapProgram';
		
		private var mNumEdges:int = 32;
		private var excircleRadius:Number;
		
		// Geometry data
		
		private var vertexData:VertexData;
		private var vertexBuffer:VertexBuffer3D;
		private var indexData:Vector.<uint>;
		private var indexBuffer:IndexBuffer3D;
		
		// Helpers
		
		private static var sHelperMatrix:Matrix = new Matrix();
		private static var position:Point = new Point();
		private static var sRenderAlpha:Vector.<Number> = new <Number>[1.0, 1.0, 1.0, 1.0];
		private static var tmpBounds:Rectangle = new Rectangle();
		
		// Lightmap
		
		private static var constants:Vector.<Number> = new <Number>[0.5, 1.0, 2.0, 0.0];
		private static var constants2:Vector.<Number> = new <Number>[3.0, 0.0, 0.0, 0.0];
		private static var lightProps:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private static var lightProps2:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private static var lightColor:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private static var halfVec:Vector.<Number> = new <Number>[0.0, 0.0, 1.0, 0.0];
		private static var lightPosition:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private static var attenuationConstants:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private static var atan2Constants:Vector.<Number> = new <Number>[
			0, 0, Math.PI * 2, 0, 
			2.220446049250313e-16, 0.7853981634, 0.1821, 0.9675, // atan2 magic numbers
		];
		private static var blurConstants:Vector.<Number> = new <Number>[
			0.05, 0.09, 0.12, 0.15, 
			1.0, 2.0, 3.0, 4.0,
			0.18, -1.0, 0.0, 0.0
		];
		private var screenDimensions:Vector.<Number> = new <Number>[0, 0, 0, 0];
		
		// Shadowmap
		
		private static var lightBounds:Vector.<Number> = new Vector.<Number>();
		private static var shadowmapConstants:Vector.<Number> = new <Number>[Math.PI, Math.PI * 1.5, 0.0, 0.1];
		private static var shadowmapConstants2:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		
		// Light direction
		
		private static var lightDirection:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private static var lightAngle:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		
		private var pointA:Point = new Point();
		private var pointB:Point = new Point();
		private var pointC:Point = new Point();
		private var zero:Point = new Point(0, 0);
		
		// Constants
		
		private static var PIXELS_PER_DRAW_CALL:int;
		
		public function SpotLight(color:uint = 0xFFFFFF, strength:Number = 1.0, radius:Number = 50, attenuation:Number = 15)
		{
			super(color, strength);
			
			this.radius = radius;
			this.attenuation = 15;
			this.strength = strength;
			
			// Handle lost context			
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
		
		/**
		 * Look at specific point in global (stage) coordinates.
		 */
		public function lookAt(point:Point):void
		{
			pointA.setTo(point.x, point.y);
			pointB.setTo(x, y);
			parent.localToGlobal(pointB, pointB);
			pointA.setTo(pointA.x - pointB.x, pointA.y - pointB.y);
			
			var atan2:Number = Math.atan2(-pointA.y, pointA.x);
			rotation = -(atan2 < 0 ? Math.PI * 2 + atan2 : atan2) - angle / 2;
		}
		
		/*-----------------------------
		Overrides
		-----------------------------*/
		
		public override function dispose():void
		{
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			if (vertexBuffer) vertexBuffer.dispose();
			if (indexBuffer)  indexBuffer.dispose();
			
			super.dispose();
		}
		
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if (resultRect == null) resultRect = new Rectangle();
			
			var transformationMatrix:Matrix = targetSpace == this ? 
				null : getTransformationMatrix(targetSpace, sHelperMatrix);
			
			return vertexData.getBounds(transformationMatrix, 0, -1, resultRect);
		}
		
		/**
		 * Renders light to lightmap.
		 */
		override public function render(support:RenderSupport, alpha:Number):void
		{
			if(DeferredShadingContainer.renderPass != RenderPass.LIGHTS)
			{
				return;
			}
			
			// always call this method when you write custom rendering code!
			// it causes all previously batched quads/images to render.
			support.finishQuadBatch();
			
			// make this call to keep the statistics display in sync.
			support.raiseDrawCount();		
			
			sRenderAlpha[0] = sRenderAlpha[1] = sRenderAlpha[2] = 1.0;
			sRenderAlpha[3] = alpha * this.alpha;
			
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			// Don`t apply regular blend mode
			// support.applyBlendMode(false);
			
			// Set constants
			
			// Light direction vector
			// Calculate global rotation up to the root
			
			calculateGlobalScaleAndRotation();
			
			lightDirection[0] = Math.cos(globalRotationAtCenter);
			lightDirection[1] = Math.sin(globalRotationAtCenter);
			
			// Position
			
			position.setTo(0, 0);
			localToGlobal(position, position);
			
			lightPosition[0] = position.x;
			lightPosition[1] = position.y;	
			lightPosition[2] = Math.sqrt((radius * radius) / 2);			
					
			var scaledRadius:Number = _radius * globalScale;
				
			lightProps[0] = scaledRadius;
			lightProps[1] = _strength;
			lightProps[2] = 1 / scaledRadius;
			lightProps[3] = scaledRadius * scaledRadius;
			
			lightProps2[0] = _castsShadows ? 1.0 : 0.0;
			
			lightColor[0] = _colorR;
			lightColor[1] = _colorG;
			lightColor[2] = _colorB;
			
			attenuationConstants[0] = _attenuation;
			attenuationConstants[1] = 1 / (attenuationConstants[0] + 1);
			attenuationConstants[2] = 1 - attenuationConstants[1];
			
			screenDimensions[0] = stage.stageWidth;
			screenDimensions[1] = stage.stageHeight;
			
			// Light angle
			
			lightAngle[0] = Math.cos(_angle / 2);
			lightAngle[1] = 1 / (1 - lightAngle[0]);
			
			// Activate program (shader) and set the required buffers / constants 
			
			context.setProgram(Starling.current.getProgram(_castsShadows ? SPOTLIGHT_PROGRAM_WITH_SHADOWS : SPOTLIGHT_PROGRAM));
			context.setVertexBufferAt(0, vertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_2); 
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, support.mvpMatrix3D, true);   
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, constants, 1);
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, constants, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, lightPosition, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, lightProps, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, lightColor, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 4, halfVec, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 5, attenuationConstants, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 7, lightProps2, 1);
			
			if(_castsShadows)
			{
				var globalMax:Number = globalRotationAtCenter + angle / 2;
				var globalMin:Number = globalRotationAtCenter - angle / 2;
				var out:Boolean = globalMin < 0 || globalMax > Math.PI * 2;
				
				atan2Constants[0] = out ? globalRotationAtCenterUnnormalized - angle / 2 : globalMin;
				atan2Constants[1] = angle;
				atan2Constants[3] = out ? -100.0 : 0.0;
				
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 8, atan2Constants, 2);
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 10, constants2, 1);
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 11, blurConstants, 3);
			}			
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 14, screenDimensions, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 15, lightDirection, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 16, lightAngle, 1);
			context.drawTriangles(indexBuffer, 0, mNumEdges);
			
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
			
			globalRotationAtCenter = NaN;
			globalScale = NaN;
		}
		
		private var globalRotationAtCenter:Number;
		private var globalRotationAtCenterUnnormalized:Number;
		private var globalScale:Number;
		
		private function calculateGlobalScaleAndRotation():void
		{
			// Calculate only once per frame
			if(!isNaN(globalScale)) return;
			
			var parent:DisplayObject = this;
			globalRotationAtCenter = angle / 2;
			globalScale = 1;
			
			while(parent)
			{
				globalRotationAtCenter += parent.rotation;				
				globalScale *= parent.scaleX;
				parent = parent.parent;
			}
			
			globalRotationAtCenter = normalizeAngle(globalRotationAtCenter);
			globalRotationAtCenterUnnormalized = -globalRotationAtCenter;
			
			// Convert to [0, 2Pi], anti-clockwise
			globalRotationAtCenter = globalRotationAtCenter < 0 ? -globalRotationAtCenter : 2 * Math.PI - globalRotationAtCenter;
		}
		
		private function normalizeAngle(angle:Number):Number
		{
			// move to equivalent value in range [0 deg, 360 deg] without a loop
			angle = angle % (Math.PI * 2);
			
			// move to [-180 deg, +180 deg]
			if (angle < -Math.PI) angle += Math.PI * 2;
			if (angle >  Math.PI) angle -= Math.PI * 2;
			
			return angle;
		}
		
		/**
		 * Renders shadow map for this light.
		 */
		public function renderShadowMap(
			support:RenderSupport,
			occluders:Texture,
			vertexBuffer:VertexBuffer3D,
			indexBuffer:IndexBuffer3D
		):void
		{			
			getBounds(stage, tmpBounds);
			var context:Context3D = Starling.context;
			
			pointA.setTo(0, 0);
			pointB.setTo(0, _radius);
			
			localToGlobal(pointA, pointA);
			localToGlobal(pointB, pointB);		
			
			var dist:Number = Point.distance(pointA, pointB);
			var diag:Number = Math.sqrt(dist * dist + dist * dist);
			
			tmpBounds.setTo(
				pointA.x + Math.cos(Math.PI / 2 + Math.PI / 4) * diag,
				pointA.y - Math.sin(Math.PI / 2 + Math.PI / 4) * diag,
				dist * 2,
				dist * 2
			);
			
			var uStart:Number = (tmpBounds.x / stage.stageWidth) + (1 / tmpBounds.width) * 0.5;
			var vStart:Number = (tmpBounds.y / stage.stageHeight) + (1 / tmpBounds.height) * 0.5;			
			var uWidth:Number = tmpBounds.width / stage.stageWidth;
			var vHeight:Number = tmpBounds.height / stage.stageHeight;
			var numBlocks:Number = Math.ceil(radius / PIXELS_PER_DRAW_CALL);			
			var vCurrentBlockOffset:Number = PIXELS_PER_DRAW_CALL;
			
			// Split shadowmap generation to multiple draws as AGAL don't support loops yet
			// Offset sampling coords by half-texel to sample exactly at the middle of each texel
			
			// Calculate start coordinates and step sizes
			// vStart will be recalculated before each draw call
			
			// Set constants
			
			lightBounds[0] = uStart;
			lightBounds[1] = vStart;
			lightBounds[2] = uWidth;
			lightBounds[3] = vHeight;
			
			calculateGlobalScaleAndRotation();
			
			shadowmapConstants[0] = globalRotationAtCenter;
			shadowmapConstants[1] = angle / 2;
			
			shadowmapConstants2[2] = _radius;
			shadowmapConstants2[3] = 1 / tmpBounds.height * 0.5;
			
			context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);                 
			context.setTextureAt(0, occluders.base);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, lightBounds);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, shadowmapConstants);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, constants);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, shadowmapConstants2);
			
			context.setProgram(Starling.current.getProgram(SHADOWMAP_PROGRAM));
			
			for(var i:int = 0; i < numBlocks; i++)
			{
				shadowmapConstants2[1] = vCurrentBlockOffset * i;		
				context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, shadowmapConstants2);
				context.drawTriangles(indexBuffer);
				support.raiseDrawCount();
			}			
			
			// Clean up
			
			context.setVertexBufferAt(0, null);
			context.setTextureAt(0, null);		
		}
		
		/*-----------------------------
		Event handlers
		-----------------------------*/
		
		private function onContextCreated(event:Event):void
		{
			// The old context was lost, so we create new buffers and shaders			
			createBuffers();
			registerPrograms();
		}
		
		/*-----------------------------
		Helpers
		-----------------------------*/
		
		private function registerPrograms():void
		{
			var target:Starling = Starling.current;
			
			if(target.hasProgram(SPOTLIGHT_PROGRAM))
			{
				return;
			}				
			
			// va0 - position
			// vc0 - mvpMatrix (occupies 4 vectors, vc0 - vc3)			
			
			var vertexProgramCode:String = 
				ShaderUtils.joinProgramArray(
					[
						'm44 vt0, va0, vc0',
						'mov op, vt0',
						'mov v0, vt0'
					]
				);		
			
			// fc0 - constants [0.5, 1, 2, 0]
			// fc1 - light position in eye coordinates, screen width/height [x, y, z (fake), 0]
			// fc2 - light properties [radius, strength, 1 / radius, radius^2]
			// fc3 - light color [r, g, b, 0]
			// fc4 - halfVec [0, 0, 1, 0]
			// fc5 - attenuation constants [0, 0, 0, att_s]
			// fc7 - [castsShadows, 0, 0, 0]
			// fc8 - [globalMin, angle, 2PI, -100 or 0, depending whether light cone crosses boundary where atan2 restarts]
			// fc9 - [1e-10, 0.5PI, 0.0, 0.0]
			// fc10 - constants2 [3, 0, 0, 0]
			// fc11 - blur constants [0.05, 0.09, 0.12, 0.15]
			// fc12 - blur constants [1, 2, 3, 4]
			// fc13 - blur constants [0.16, -1, 0, 0]
			// fc14 - [screenWidth, screenHeight, 0, 0]
			// fc15 - [light direction x, light direction y, 0, 0]
			// fc16 - [cos(light angle / 2), 1 / (1 - cos(light angle / 2)), 0, 0]
			
			var fragmentProgramCode:String =
				ShaderUtils.joinProgramArray(
					[
						// Unpack screen coords to [0, 1] by
						// multiplying by 0.5 and then adding 0.5						
						
						'mul ft0.xyxy, v0.xyxy, fc0.xxxx',
						'add ft0.xy, ft0.xy, fc0.xx',
						'sub ft0.y, fc0.y, ft0.y',
						
						// Sample normals to ft1
						
						'tex ft1, ft0.xy, fs0 <2d, clamp, linear, mipnone>',
						'sub ft1.y, fc0.y, ft1.y ', // y-axis should increase downwards
						
						// Then unpack normals from [0, 1] to [-1, 1]
						// by multiplying by 2 and then subtracting 1
						
						'mul ft1.xyz, ft1.xyz, fc0.zzz',
						'sub ft1.xyz, ft1.xyz, fc0.yyy',
						
						'nrm ft1.xyz, ft1.xyz',
						
						// Sample depth to ft2 
						
						'tex ft2, ft0.xy, fs1 <2d, clamp, linear, mipnone>',
						
						// Put specular power and specular intensity to ft0.zw
						// Those are stored in yz of depth
						
						'mov ft0.z, ft2.y',
						'mov ft0.w, ft2.z',
						
						// Calculate pixel position in eye space
						
						'mul ft3.xyxy, ft0.xyxy, fc14.xyxy',
						'mov ft3.z, fc0.w',
						'mov ft21.xyz, ft3.xyz', // save for shadow calculations
						
						/*-----------------------
						Calculate coincidence 
						between light and surface 
						normal
						-----------------------*/
						
						// float3 lightDirection3D = lightPosition.xyz - pixelPosition.xyz;
						// z(light) = positive float, z(pixel) = 0
						'sub ft3.xyz, fc1.xyz, ft3.xyz',
						'mov ft3.w, fc0.w',
						
						// Save length(lightDirection2D) to ft20.x for later shadow calculations
						'pow ft20.x, ft3.x, fc0.z',
						'pow ft20.y, ft3.y, fc0.z',
						'add ft20.x, ft20.x, ft20.y',
						'sqt ft20.x, ft20.x',
						'div ft20.x, ft20.x, fc2.x',
						
						// float3 lightDirNorm = normalize(lightDirection3D);
						'nrm ft7.xyz, ft3.xyz',
						
						// float amount = max(dot(normal, lightDirNorm), 0);
						// Put it in ft5.x
						'dp3 ft5.x, ft1.xyz, ft7.xyz',
						'max ft5.x, ft5.x, fc0.w',			
						
						/*-----------------------
						Calculate attenuation
						-----------------------*/
						
						// Linear attenuation
						// http://blog.slindev.com/2011/01/10/natural-light-attenuation/
						// Put it in ft5.y				
						'mov ft3.z, fc0.w', // attenuation is calculated in 2D
						'dp3 ft5.y, ft3.xyz, ft3.xyz',
						'div ft5.y, ft5.y, fc2.w',
						'mul ft5.y, ft5.y, fc5.x',
						'add ft5.y, ft5.y, fc0.y',
						'rcp ft5.y, ft5.y',						
						'sub ft5.y, ft5.y, fc5.y',
						'div ft5.y, ft5.y, fc5.z',
						
						/*-----------------------
						Calculate specular
						-----------------------*/
						
						'neg ft7.xyz, ft7.xyz',
						'dp3 ft6.x, ft7.xyz, ft1.xyz',
						'mul ft6.xyz, ft6.xxx, fc0.z', //35
						'mul ft6.xyz, ft6.xxx, ft1.xyz',
						'sub ft6.xyz, ft7.xyz, ft6.xyz',
						
						'dp3 ft6.x, ft6.xyz, fc4.xyz',
						'max ft6.x, ft6.x, fc0.w',
						'pow ft5.z, ft6.x, ft0.z',
						
						/*-----------------------
						Finalize
						-----------------------*/
						
						// Output.Color = lightColor * coneAttenuation * lightStrength
						'mul ft6.xyz, ft5.yyy, fc3.xyz',
						'mul ft6.xyz, ft6.xyz, ft5.x',
						
						// + (coneAttenuation * specular * specularStrength)						
						'mul ft7.x, ft5.y, ft5.z',
						'mul ft7.x, ft7.x, ft0.w',
						'mov ft6.w, ft7.x',
						
						// Light intensity at the corners of the cone
						// Those depend on the angle between current beam and center beam
						
						// Point dir vector
						'nrm ft4.xyz, ft3.xyz',
						'neg ft4.x, ft4.x',						
						'dp3 ft12.x, ft4.xyz, fc15.xyz',					
						
						// Scale all calculated coefs to be in range [0, 1]
						// Put resulting coef into ft7.x, that one isn't used by shadows shader part
					
						'sub ft12.x, ft12.x, fc16.x',
						'mul ft7.x, ft12.x, fc16.y',
						
						// Shadows part :>
						
						'<shadows>',
						
						// Multiply diffuse color by calculated light amounts
						
						'tex ft1, ft0.xy, fs4 <2d, clamp, linear, mipnone>',
						
						// light = (specular * lightColor + diffuseLight) * lightStrength
						'mul ft2.xyz, ft6.www, fc3.xyz,',
						'add ft2.xyz, ft2.xyz, ft6.xyz',
						'mul ft2.xyz, ft2.xyz, fc2.yyy ',
						'mov ft2.w, fc0.y',
						
						// Multiply result by light intensity coef
						'mul ft2.xyz, ft2.xyz, ft7.x',
						
						// light * diffuseRT
						'mul ft2.xyz, ft2.xyz, ft1.xyz',
						'mov oc, ft2',
					]
				);
			
			var vertexProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, DeferredShadingContainer.AGAL_VERSION);
			
			var fragmentProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode.replace('<shadows>', ''), DeferredShadingContainer.AGAL_VERSION);
			
			target.registerProgram(SPOTLIGHT_PROGRAM, vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
			
			// Register point light program with shadows			
			
			var shadowsCode:String =
				ShaderUtils.joinProgramArray(
					[
						/*--------------------------
						Render shadows
						--------------------------*/				
						
						// Sample occluders
						'tex ft10, ft0.xy, fs3 <2d, clamp, linear, nomip>',
						
						// Calculate pixel position in lights own coordinate system, where 
						// light center is (0, 0) and Y axis increases downwards
						'sub ft11.xy, ft21.xy, fc1.xy',
						'div ft11.xy, ft11.xy, fc2.x',	
						'neg ft11.y, ft11.y',
						'mov ft11.zw, fc0.ww',
						
						/*--------------------------------
						Calculate atan2
						--------------------------------*/
						
						// From: http://wonderfl.net/c/mS2W/
						
						'abs ft8, ft11' /* ft8 = |x|, |y| */,
						/* sge, because dated AGALMiniAssembler does not have seq */
						'sge ft8, ft11, ft8' /* ft8.zw are both =1 now, since ft11.zw were =0 */,
						'add ft8.xyw, ft8.xyw, ft8.xyw',
						'sub ft8.xy, ft8.xy, ft8.zz' /* ft8 = sgn(x), sgn(y), 1, 2 */,
						'sub ft8.w, ft8.w, ft8.x' /* ft8.w = '(partSignX, 1.0)' = 2 - sgn(x) */,
						'mul ft8.w, ft8.w, fc9.y' /* ft8.w = '(partSignX, 1.0) * 0.7853981634' */,
						'mul ft8.z, ft8.y, ft11.y' /* ft8.z = 'y * sign' */,
						'add ft8.z, ft8.z, fc9.x' /* ft8.z = 'y * sign, 2.220446049250313e-16' or 'absYandR' initial value */,
						'mul ft9.x, ft8.x, ft8.z' /* ft9.x = 'signX * absYandR' */,
						'sub ft9.x, ft11.x, ft9.x' /* ft9.x = '(x - signX * absYandR)' */,
						'mul ft9.y, ft8.x, ft11.x' /* ft9.y = 'signX * x' */,
						'add ft9.y, ft9.y, ft8.z' /* ft9.y = '(signX * x, absYandR)' */,
						'div ft8.z, ft9.x, ft9.y' /* ft8.z = '(x - signX * absYandR) / (signX * x, absYandR)' or 'absYandR' final value */,
						'mul ft9.x, ft8.z, ft8.z' /* ft9.x = 'absYandR * absYandR' */,
						'mul ft9.x, ft9.x, fc9.z' /* ft9.x = '0.1821 * absYandR * absYandR' */,
						'sub ft9.x, ft9.x, fc9.w' /* ft9.x = '(0.1821 * absYandR * absYandR - 0.9675)' */,
						'mul ft9.x, ft9.x, ft8.z' /* ft9.x = '(0.1821 * absYandR * absYandR - 0.9675) * absYandR' */,
						'add ft9.x, ft9.x, ft8.w' /* ft9.x = '(partSignX, 1.0) * 0.7853981634, (0.1821 * absYandR * absYandR - 0.9675) * absYandR' */,
						'mul ft9.x, ft9.x, ft8.y' /* ft9.x = '((partSignX, 1.0) * 0.7853981634, (0.1821 * absYandR * absYandR - 0.9675) * absYandR) * sign' */,						
						
						// convert atan result to range [0, 2pi]
						'ifl ft9.x, fc8.w',
							'neg ft9.x, ft9.x',
							'sub ft9.x, fc8.z, ft9.x',
						'eif',						
						
						// atan result is in range [a, b], compress to 0..1: (angle + pi)/(2 * pi)
						'sub ft9.x, ft9.x, fc8.x',
						'div ft9.x, ft9.x, fc8.y',
						'sub ft9.x, fc0.y, ft9.x',
						
						/*--------------------------------
						Apply gaussian blur
						--------------------------------*/
						
						// float blur = (1./resolution.x)  * smoothstep(0., 1., r);
						// smoothstep = t * t * (3.0 - 2.0 * t), t = r
						'mul ft11.x, fc0.z, ft20.x',
						'sub ft11.x, fc10.x, ft11.x',
						'mul ft11.x, ft11.x, ft20.x',
						'mul ft11.x, ft11.x, ft20.x',
						'mul ft11.x, ft11.x, fc2.z',
						
						// We`ll sum into ft12.x
						// sum = 0
						'mov ft12.x, fc0.w',
						
						// Sample multiple times for blur			
						// sum += sample(vec2(tc.x - 4.0*blur, tc.y), r) * 0.05;							
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.w',
						'sub ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.x',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x - 3.0*blur, tc.y), r) * 0.09;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.z',
						'sub ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.y',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x - 2.0*blur, tc.y), r) * 0.12;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.y',
						'sub ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.z',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x - 1.0*blur, tc.y), r) * 0.15;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.x',
						'sub ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.w',
						'add ft12.x, ft12.x, ft13.x',
						// sum += center * 0.16;
						'tex ft14, ft9.xy, fs2 <2d, clamp, linear, nomip>',							
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc13.x',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x + 1.0*blur, tc.y), r) * 0.15;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.x',
						'add ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.w',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x + 2.0*blur, tc.y), r) * 0.12;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.y',
						'add ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.z',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x + 3.0*blur, tc.y), r) * 0.09;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.z',
						'add ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.y',
						'add ft12.x, ft12.x, ft13.x',
						//sum += sample(vec2(tc.x + 4.0*blur, tc.y), r) * 0.05;
						'mov ft13.x, ft9.x',
						'mul ft13.y, ft11.x, fc12.w',
						'add ft13.x, ft13.x, ft13.y',
						'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
						'sge ft13.x, ft20.x, ft14.x',
						'mul ft13.x, ft13.x, fc11.x',
						'add ft12.x, ft12.x, ft13.x',
						
						// Final coef
						'sub ft12.x, fc0.y, ft12.x',
						
						/*--------------------------------
						Result
						--------------------------------*/
						
						// Draw shadow everywhere except pixels that overlap occluders						
						'sub ft10.x, fc0.y, ft10.x',
						'add ft12.x, ft12.x, ft10.x',						
						'mul ft6, ft6, ft12.x'
					]
				);
			
			vertexProgramAssembler = new AGALMiniAssembler();
			vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, DeferredShadingContainer.AGAL_VERSION);
			
			fragmentProgramAssembler = new AGALMiniAssembler();
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode.replace('<shadows>', shadowsCode), DeferredShadingContainer.AGAL_VERSION);
			
			target.registerProgram(SPOTLIGHT_PROGRAM_WITH_SHADOWS, vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
			
			// Register shadowmap program
			
			vertexProgramCode = 
				ShaderUtils.joinProgramArray(
					[						
						// Pass along unpacked screen cords
						'mov v0, va0',						
						'mov op, va0'
					]
				);
			
			// Constants:
			// fc0 - [uStart, vStart, uWidth, vHeight]
			// fc1 - [rotationAtCenter, angle / 2, 0, threshold]
			// fc2 - constants [0.5, 1, 2, 0]
			// fc3 - [0, vCurrentBlockOffset, lightRadius, halfFragment]
			
			fragmentProgramCode =
				ShaderUtils.joinProgramArray(
					[					
						// Calculate theta (θ)
						// float theta = rotationAtCenter - angle / 2 * u (spotlight version, u is in range [-1, 1])
						'mul ft0.x, v0.x, fc1.y',
						'sub ft0.x, fc1.x, ft0.x',
						
						// Set initial r value to current block offset
						'mov ft6.x, fc3.y',
						
						// Set initial distance to 1
						'mov ft4.x, fc2.y',
						
						/*------------------------
						LOOP GOES HERE
						------------------------*/
						'<loop>',
						
						'mov od.x, ft4.x',
						'mov oc, ft4.xxxx'
					]
				);
			
			// Calculate the number of pixels we can process using single draw call
			
			PIXELS_PER_DRAW_CALL = Math.floor((DeferredShadingContainer.OPCODE_LIMIT - 6) / 15);
			
			var i:int = PIXELS_PER_DRAW_CALL;
			var loopCode:String = '';
			
			while(i--)
			{
				// This renders single shadowmap pixel.
				// Things are a bit complicated as only square portion of the occluder map should be rendered.			
				// AGAL does not support loops as of yet, so we just have to repeat needed block
				// as many times, as it is possible while keeping opcode count below the limit.
				// PIXELS_PER_DRAW_CALL indicates how many pixels we can process in a single draw call :~
				
				// Constants:
				// same as above
				
				// Temps:
				// ft0 - [theta, r, u, -r]
				// ft6.x - currY
				
				loopCode +=
					ShaderUtils.joinProgramArray(
						[		
							// currU = r / lightRadius
							'div ft0.y, ft6.x, fc3.z',
							
							// Calculate occluder map sample coord
							// vec2 coord = vec2(r * sin(theta), r * cos(theta))/2.0 + 0.5;
							'cos ft1.x, ft0.x',
							'sin ft1.y, ft0.x',
							'mul ft2.xyxy, ft1.xyxy, ft0.yyyy',
							'mul ft2.xyxy, ft2.xyxy, fc2.x',
							'neg ft2.y, ft2.y', // y axis is inverted in UV space
							'add ft2.xy, ft2.xy, fc2.x',
							
							// Generated coords are in range [0, 1] so we should multiply those by
							// whole shadowmap area part width and height and add offsets
							'mul ft2.xyxy, ft2.xyxy, fc0.zwzw',
							'add ft2.xy, ft2.xy, fc0.xy',
							// Subtract half fragment - not sure why
							'sub ft2.xy, ft2.xy, fc3.ww',
							'tex ft3, ft2.xy, fs0 <2d, clamp, linear, mipnone>',
							
							// Check if the ray hit an occluder	(meaning current occluder map value < 1)
							// Set distance of this pixel to current distance if it lower than current one
							'ifl ft3.x, fc2.y',
								'min ft4.x, ft4.x, ft0.y',
								// break/return here would speed things a lot
							'eif',
							
							// Increment r
							'add ft6.x, ft6.x, fc2.y'
						]
					);
			}
			
			// Insert loop
			
			fragmentProgramCode = fragmentProgramCode.replace('<loop>', loopCode);
			
			vertexProgramAssembler = new AGALMiniAssembler();
			vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, DeferredShadingContainer.AGAL_VERSION);
			
			fragmentProgramAssembler = new AGALMiniAssembler();
			fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode, DeferredShadingContainer.AGAL_VERSION);
			
			target.registerProgram(SHADOWMAP_PROGRAM, vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
		}
		
		private function calculateRealRadius(radius:Number):void
		{			
			var edge:Number = (2 * radius) / (1 + Math.sqrt(2));
			excircleRadius = edge / 2 * (Math.sqrt( 4 + 2 * Math.sqrt(2) ));
		}
		
		private function setupVertices():void
		{
			var i:int;
			
			// Create vertices		
			vertexData = new VertexData(mNumEdges+1);
			
			for(i = 0; i < mNumEdges; ++i)
			{
				var edge:Point = Point.polar(excircleRadius, _angle * (i / (mNumEdges - 1)));
				vertexData.setPosition(i, edge.x, edge.y);
			}
			
			// Center vertex
			vertexData.setPosition(mNumEdges, 0.0, 0.0);
			
			// Create indices that span up the triangles			
			indexData = new <uint>[];
			
			for(i = 0; i < mNumEdges; ++i)
			{
				indexData.push(mNumEdges, i, i + 1);
			}		
		}
		
		private function createBuffers():void
		{
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			if (vertexBuffer) vertexBuffer.dispose();
			if (indexBuffer)  indexBuffer.dispose();
			
			vertexBuffer = context.createVertexBuffer(vertexData.numVertices, VertexData.ELEMENTS_PER_VERTEX);
			vertexBuffer.uploadFromVector(vertexData.rawData, 0, vertexData.numVertices);
			
			indexBuffer = context.createIndexBuffer(indexData.length);
			indexBuffer.uploadFromVector(indexData, 0, indexData.length);
		}
		
		/*-----------------------------
		Properties
		-----------------------------*/
		
		private var _attenuation:Number;
		
		public function get attenuation():Number
		{ 
			return _attenuation;
		}
		public function set attenuation(value:Number):void
		{
			_attenuation = value <= 0 ? Number.MIN_VALUE : value;
		}
		
		private var _radius:Number;
		
		public function get radius():Number
		{ 
			return _radius;
		}
		public function set radius(value:Number):void
		{
			_radius = value;
			calculateRealRadius(value);
			
			// Setup vertex data and prepare shaders			
			setupVertices();
			createBuffers();
			registerPrograms();
		}
		
		private var _castsShadows:Boolean;
		
		public function get castsShadows():Boolean
		{ 
			return _castsShadows;
		}
		public function set castsShadows(value:Boolean):void
		{
			_castsShadows = value;
			lightProps2[0] = value ? 1.0 : 0.0;
			
			if(value && !_shadowMap)
			{
				// TODO: add property textureSize
				_shadowMap = Texture.empty(512, 1, false, false, true, -1, Context3DTextureFormat.BGRA);
			}
			
			if(!value && _shadowMap)
			{
				_shadowMap.dispose();
				_shadowMap = null;
			}
		}
		
		private var _shadowMap:Texture;
		
		public function get shadowMap():Texture
		{ 
			return _shadowMap; 
		}
		
		private var _angle:Number = Math.PI / 3;
		
		/**
		 * Cone angle. In case the value does not fall in interval [0, 2π] it will be set to default of π / 3.
		 */
		public function get angle():Number
		{ 
			return _angle; 
		}
		public function set angle(value:Number):void
		{
			_angle = (value > Math.PI || value < 0) ? Math.PI / 3 : value;
			
			// Setup vertex data and prepare shaders			
			setupVertices();
			createBuffers();
			registerPrograms();
		}
	}
}