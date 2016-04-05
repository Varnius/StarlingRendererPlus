// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

/**
 * Created by Derpy on 2016.02.21.
 */
package starling.extensions.rendererPlus.lights.rendering
{
    import flash.display3D.Context3DTextureFormat;
    import flash.display3D.IndexBuffer3D;
    import flash.display3D.VertexBuffer3D;
    import flash.geom.Point;

    import starling.core.Starling;
    import starling.display.DisplayObject;
    import starling.extensions.rendererPlus.interfaces.IAreaLight;
    import starling.extensions.rendererPlus.interfaces.IShadowMappedLight;
    import starling.extensions.rendererPlus.lights.Light;
    import starling.extensions.rendererPlus.lights.SpotLight;
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;
    import starling.rendering.Painter;
    import starling.rendering.RenderState;
    import starling.textures.Texture;
    import starling.utils.MathUtil;

    use namespace renderer_internal;

    public class SpotLightStyle extends LightStyle implements IShadowMappedLight, IAreaLight
    {
        private static var shadowMapRenderer:SpotLightShadowMapRenderer = new SpotLightShadowMapRenderer();

        public var center:Point = new Point();
        public var light:Light;

        private var globalRotationAtCenter:Number;
        private var globalRotationAtCenterUnnormalized:Number;
        private var globalScale:Number;
        private var prevFrame:uint = -1;

        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var s:SpotLightStyle = meshStyle as SpotLightStyle

            _castsShadows = s.castsShadows;
            _attenuation = s.attenuation;
            _radius = s.radius;
            center = s.center;
            _angle = s.angle;
            light = s.light;
            globalRotationAtCenter = s.globalRotationAtCenter;
            globalRotationAtCenterUnnormalized = s.globalRotationAtCenterUnnormalized;
            globalScale = s.globalScale;
            prevFrame = s.prevFrame;

            super.copyFrom(meshStyle);
        }

        override public function createEffect():MeshEffect
        {
            return new SpotLightEffect();
        }

        override public function updateEffect(effect:MeshEffect, state:RenderState):void
        {
            var e:SpotLightEffect = effect as SpotLightEffect

            calculateGlobalScaleAndRotation(light, angle);

            e.castsShadows = _castsShadows;
            e.attenuation = _attenuation;
            e.radius = _radius;
            e.center = center;
            e.angle = _angle;
            e.light = light;
            e.globalRotationAtCenter = globalRotationAtCenter;
            e.globalRotationAtCenterUnnormalized = globalRotationAtCenterUnnormalized;
            e.globalScale = globalScale;

            // Derived

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
            calculateGlobalScaleAndRotation(light, angle);
            shadowMapRenderer.renderShadowMap(
                    painter,
                    occluders,
                    vertexBuffer,
                    indexBuffer,
                    _radius,
                    _angle,
                    Starling.current.stage,
                    light,
                    globalRotationAtCenter);
        }

        // Helpers

        private function calculateGlobalScaleAndRotation(target:DisplayObject, angle:Number):void
        {
            var frame:uint = Starling.painter.frameID;

            // Calculate only once per frame
            if(frame == prevFrame) return;
            prevFrame = frame;

            var parent:DisplayObject = target;
            globalRotationAtCenter = angle / 2;
            globalScale = 1;

            while(parent)
            {
                globalRotationAtCenter += parent.rotation;
                globalScale *= parent.scaleX;
                parent = parent.parent;
            }

            globalRotationAtCenter = MathUtil.normalizeAngle(globalRotationAtCenter);
            globalRotationAtCenterUnnormalized = -globalRotationAtCenter;

            // Convert to [0, 2Pi], anti-clockwise
            globalRotationAtCenter = globalRotationAtCenter < 0 ? -globalRotationAtCenter : 2 * Math.PI - globalRotationAtCenter;
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
            if(target is SpotLight) (target as SpotLight).setupVertices();
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
            if(target is SpotLight) (target as SpotLight).setupVertices();
        }
    }
}
