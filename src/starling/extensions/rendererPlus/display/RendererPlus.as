// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.display
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
    import flash.utils.Dictionary;

    import starling.core.Starling;
    import starling.core.starling_internal;
    import starling.display.BlendMode;
    import starling.display.DisplayObject;
    import starling.display.DisplayObjectContainer;
    import starling.display.Mesh;
    import starling.display.Quad;
    import starling.events.Event;
    import starling.extensions.rendererPlus.RenderPass;
    import starling.extensions.rendererPlus.interfaces.IAreaLight;
    import starling.extensions.rendererPlus.interfaces.IShadowMappedLight;
    import starling.extensions.rendererPlus.lights.AmbientLight;
    import starling.extensions.rendererPlus.lights.Light;
    import starling.extensions.rendererPlus.lights.rendering.LightStyle;
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.extensions.rendererPlus.rendering.OccluderStyle;
    import starling.extensions.utils.ShaderUtils;
    import starling.rendering.Painter;
    import starling.rendering.Program;
    import starling.textures.Texture;
    import starling.utils.SystemUtil;

    use namespace renderer_internal;
    use namespace starling_internal;

    /**
     * DeferredRenderer. Serves as a container for all other display objects
     * that should have lighting applied to them.
     */
    public class RendererPlus extends DisplayObjectContainer
    {
        private static const AMBIENT_PROGRAM:String = 'AmbientProgram';

        public static var defaultNormalMap:Texture;
        public static var defaultDepthMap:Texture;
        public static var defaultSpecularMap:Texture;

        public static var OPCODE_LIMIT:int;
        public static var AGAL_VERSION:int;

        private static var RTIndices:Vector.<int>;
        {
            // On Android, MRT targets seem to be scrambled in this order
            if(SystemUtil.platform == 'AND')
                RTIndices = new <int>[2, 0, 1];
            else
                RTIndices = new <int>[0, 1, 2];
        }

        // Quad

        protected var overlayVertexBuffer:VertexBuffer3D;
        protected var overlayIndexBuffer:IndexBuffer3D;
        protected var vertices:Vector.<Number> = new <Number>[-1, 1, 0, 0, 0, -1, -1, 0, 0, 1, 1, 1, 0, 1, 0, 1, -1, 0, 1, 1];
        protected var indices:Vector.<uint> = new <uint>[0, 1, 2, 2, 1, 3];

        // Program constants

        private var ambient:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 1.0];

        public static var _renderPass:String = RenderPass.NORMAL;

        public static function set renderPass(value:String):void
        {
            _renderPass = value;
        }

        public static function get renderPass():String
        {
            return _renderPass;
        }

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

        /**
         * Class constructor. Creates a new instance of RendererPlus.
         */
        public function RendererPlus()
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
                trace('[StarlingRendererPlus] Current Stage3D profile is not supported by StarlingRendererPlus.');

            prepare();
            registerPrograms();

            // Handle lost context
            Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
        }

        // Public

        override public function addChildAt(child:DisplayObject, index:int):DisplayObject
        {
            if(child is Light)
            {
                lights.push(child as Light);
            }

            return super.addChildAt(child, index);
        }

        override public function removeChildAt(index:int, dispose:Boolean = false):DisplayObject
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

        // Render

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
            // No difference for normals or depth because those are not calculated at the run time but all RTs must be same format

            diffuseRT = Texture.empty(w, h, false, false, true, 1, Context3DTextureFormat.RGBA_HALF_FLOAT);
            normalsRT = Texture.empty(w, h, false, false, true, 1, Context3DTextureFormat.RGBA_HALF_FLOAT);
            depthRT = Texture.empty(w, h, false, false, true, 1, Context3DTextureFormat.RGBA_HALF_FLOAT);
            occludersRT = Texture.empty(w, h, false, false, true, 1, Context3DTextureFormat.BGRA);

            MRTPassRenderTargets = new Vector.<Texture>();
            MRTPassRenderTargets.push(diffuseRT, normalsRT, depthRT);

            // Default maps

            var bd:BitmapData = new BitmapData(4, 4);
            bd.fillRect(new Rectangle(0, 0, 4, 4), 0xFF8080FF);
            defaultNormalMap = Texture.fromBitmapData(bd, false);

            bd.fillRect(new Rectangle(0, 0, 4, 4), 0xFFFFFFFF);
            defaultSpecularMap = Texture.fromBitmapData(bd, false);

            bd.fillRect(new Rectangle(0, 0, 4, 4), 0xFF000000);
            defaultDepthMap = Texture.fromBitmapData(bd, false);

            prepared = true;
        }

        private function registerPrograms():void
        {
            var target:Painter = Starling.painter;

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

            target.registerProgram(AMBIENT_PROGRAM, new Program(vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode));
        }

        override public function render(painter:Painter):void
        {
            painter.excludeFromCache(this);
            var obj:DisplayObject;

            if(!prepared) prepare();
            if(!lights.length) return;

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

                if(!l.visible || !l.parent) continue;

                l.getBounds(stage, tmpBounds);

                if(stageBounds.containsRect(tmpBounds) || stageBounds.intersects(tmpBounds)) visibleLights.push(l);
            }

            /*----------------------------------
             MRT pass
             ----------------------------------*/

            var context:Context3D = Starling.context;
            var isVisible:Boolean;
            var prevRenderTarget:Texture = painter.state.renderTarget;

            // Set render targets, clear them and render background only

            painter.state.setRenderTarget(MRTPassRenderTargets[RTIndices[0]], false, 0);
            context.setRenderToTexture(MRTPassRenderTargets[RTIndices[1]].base, false, 0, 0, 1);
            context.setRenderToTexture(MRTPassRenderTargets[RTIndices[2]].base, false, 0, 0, 2);

            var prevPass:String = renderPass;
            renderPass = RenderPass.MRT;

            painter.clear();
            super.render(painter);

            painter.state.setRenderTarget(prevRenderTarget);
            context.setRenderToTexture(null, false, 0, 0, 1);
            context.setRenderToTexture(null, false, 0, 0, 2);

            /*----------------------------------
             Shadows - occluder pass
             ----------------------------------*/

            // todo: maybe move this to mrt pass??? (as a single channel in depth target)
            // but probably not possible without breaking batching :>

            renderPass = RenderPass.OCCLUDERS;

            painter.pushState();
            painter.state.setRenderTarget(occludersRT);
            painter.clear(0xFFFFFF, 1.0);

            for each(var o:Mesh in occluders)
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
                    painter.state.setModelviewMatricesToIdentity();
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
                        painter.state.transformModelviewMatrix(obj.transformationMatrix);
                    }

                    // Tint quads/images black
                    // A special OccluderStyle is used for that

                    styleByMesh[o] = o.style;
                    o.style = new OccluderStyle();
                    o.render(painter);
                }
            }

            painter.finishMeshBatch();

            for(var mesh:Mesh in styleByMesh)
            {
                _occluderStylePool.push(mesh.style);
                mesh.style = styleByMesh[mesh];
                delete styleByMesh[mesh];
            }

            /*----------------------------------
             Shadows - shadowmap pass
             ----------------------------------*/

            renderPass = RenderPass.SHADOWMAP;

            for each(l in visibleLights)
            {
                var shadowMappedLight:IShadowMappedLight = l.style as IShadowMappedLight;

                if(!shadowMappedLight || (shadowMappedLight && !shadowMappedLight.castsShadows))
                {
                    continue;
                }

                context.setRenderToTexture(shadowMappedLight.shadowMap.base, true, 0);
                context.clear(0.0, 0.0, 0.0, 1.0, 1.0);
                context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
                context.setDepthTest(true, Context3DCompareMode.LESS_EQUAL);

                shadowMappedLight.renderShadowMap(
                        painter,
                        occludersRT,
                        overlayVertexBuffer,
                        overlayIndexBuffer
                );
            }

            context.setDepthTest(false, Context3DCompareMode.ALWAYS);

            /*----------------------------------
             Light pass
             ----------------------------------*/

            painter.popState();

            if(lights.length)
            {
                renderPass = RenderPass.LIGHTS;

                // Bind textures required by ambient light

                context.setTextureAt(4, diffuseRT.base);
                painter.pushState();
                painter.clear(0x000000, 1.0);
                painter.state.blendMode = BlendMode.ADD;

                if(ambientLight)
                {
                    // Render ambient light as full-screen quad
                    var ambientStyle:LightStyle = ambientLight.style as LightStyle;

                    ambient[0] = ambientStyle._colorR;
                    ambient[1] = ambientStyle._colorG;
                    ambient[2] = ambientStyle._colorB;

                    context.setVertexBufferAt(0, overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
                    context.setVertexBufferAt(1, overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
                    painter.getProgram(AMBIENT_PROGRAM).activate(context);
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, ambient, 1);
                    context.drawTriangles(overlayIndexBuffer);
                    context.setVertexBufferAt(1, null);
                    painter.drawCount += 1;
                }

                // Bind textures required by other types of lights

                context.setTextureAt(0, normalsRT.base);
                context.setTextureAt(1, depthRT.base);

                // Render area lights

                for each(l in visibleLights)
                {
                    shadowMappedLight = l.style as IShadowMappedLight;

                    if(l.style is IAreaLight && l.stage)
                    {
                        if(shadowMappedLight && shadowMappedLight.castsShadows)
                        {
                            context.setTextureAt(2, shadowMappedLight.shadowMap.base);
                            context.setTextureAt(3, occludersRT.base);
                        }

                        painter.state.setModelviewMatricesToIdentity();

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
                            painter.state.transformModelviewMatrix(obj.transformationMatrix);
                        }

                        l.render(painter);
                    }
                }

                if(shadowMappedLight && shadowMappedLight.castsShadows)
                {
                    context.setTextureAt(2, null);
                    context.setTextureAt(3, null);
                }

                painter.finishMeshBatch();

                context.setTextureAt(0, null);
                context.setTextureAt(1, null);
                context.setTextureAt(4, null);

                painter.popState();
            }

            renderPass = prevPass;
        }

        // OccluderStyle pool

        private const styleByMesh:Dictionary = new Dictionary();
        private static const _occluderStylePool:Vector.<OccluderStyle> = new <OccluderStyle>[];

        private function getOccluderStyle():OccluderStyle
        {
            if(_occluderStylePool.length)
            {
                return _occluderStylePool.pop();
            }
            else
            {
                return new OccluderStyle();
            }
        }

        // Event handlers

        private function onContextCreated(event:Event):void
        {
            prepared = false;
            prepare();
            registerPrograms();
            setRequiresRedraw();
        }
    }
}