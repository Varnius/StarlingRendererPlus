// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.lights.rendering
{
    import flash.display3D.Context3DTextureFormat;
    import flash.display3D.IndexBuffer3D;
    import flash.display3D.VertexBuffer3D;
    import flash.geom.Point;

    import starling.core.Starling;
    import starling.extensions.rendererPlus.interfaces.IAreaLight;
    import starling.extensions.rendererPlus.interfaces.IShadowMappedLight;
    import starling.extensions.rendererPlus.lights.Light;
    import starling.extensions.rendererPlus.lights.PointLight;
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.rendering.MeshEffect;
    import starling.rendering.Painter;
    import starling.rendering.RenderState;
    import starling.styles.MeshStyle;
    import starling.textures.Texture;

    use namespace renderer_internal;

    public class PointLightStyle extends LightStyle implements IShadowMappedLight, IAreaLight
    {
        private static var shadowMapRenderer:PointLightShadowMapRenderer = new PointLightShadowMapRenderer();

        public var center:Point = new Point();
        public var light:Light;

        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var s:PointLightStyle = meshStyle as PointLightStyle

            _castsShadows = s.castsShadows;
            _attenuation = s.attenuation;
            _radius = s.radius;
            center = s.center;
            light = s.light;

            super.copyFrom(meshStyle);
        }

        override public function createEffect():MeshEffect
        {
            return new PointLightEffect();
        }

        override public function updateEffect(effect:MeshEffect, state:RenderState):void
        {
            var e:PointLightEffect = effect as PointLightEffect;

            e.castsShadows = _castsShadows;
            e.attenuation = _attenuation;
            e.light = light;
            e.radius = _radius;
            e.center = center;
            e.strength = _strength;
            e.colorR = _colorR;
            e.colorG = _colorG;
            e.colorB = _colorB;

            super.updateEffect(effect, state);
        }

        override public function canBatchWith(meshStyle:MeshStyle):Boolean
        {
            // Can't really batch with other lights since some shader params (like light position) are set per-light
            return false;
        }

        public function renderShadowMap(painter:Painter,
                                        occluders:Texture,
                                        vertexBuffer:VertexBuffer3D,
                                        indexBuffer:IndexBuffer3D):void
        {
            shadowMapRenderer.renderShadowMap(painter, occluders, vertexBuffer, indexBuffer, _radius, Starling.current.stage, light)
        }

        // Props

        private var _attenuation:Number = 15.0;

        public function get attenuation():Number
        {
            return _attenuation;
        }

        public function set attenuation(value:Number):void
        {
            _attenuation = value <= 0 ? Number.MIN_VALUE : value;
        }

        private var _radius:Number = 100.0;

        public function get radius():Number
        {
            return _radius;
        }

        public function set radius(value:Number):void
        {
            _radius = value;
            calculateRealRadius(value);

            // Setup vertex data and prepare shaders
            if(target is PointLight) (target as PointLight).setupVertices();
        }

        public var excircleRadius:Number;

        private function calculateRealRadius(radius:Number):void
        {
            var edge:Number = (2 * radius) / (1 + Math.sqrt(2));
            excircleRadius = edge / 2 * (Math.sqrt(4 + 2 * Math.sqrt(2)));
        }

        private var _castsShadows:Boolean;

        public function get castsShadows():Boolean
        {
            return _castsShadows;
        }

        public function set castsShadows(value:Boolean):void
        {
            _castsShadows = value;

            if(value && !_shadowMap)
            {
                // todo: add property textureSize
                _shadowMap = Texture.empty(512, 1, false, false, true, 1, Context3DTextureFormat.BGRA);
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
    }
}
