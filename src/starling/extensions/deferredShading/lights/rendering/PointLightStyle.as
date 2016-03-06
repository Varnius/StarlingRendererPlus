/**
 * Created by Derpy on 2016.02.21.
 */
package starling.extensions.deferredShading.lights.rendering
{
    import flash.display3D.Context3DTextureFormat;
    import flash.display3D.IndexBuffer3D;
    import flash.display3D.VertexBuffer3D;
    import flash.geom.Point;

    import starling.extensions.deferredShading.interfaces.IAreaLight;
    import starling.extensions.deferredShading.interfaces.IShadowMappedLight;
    import starling.extensions.deferredShading.lights.PointLight;
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;
    import starling.rendering.Painter;
    import starling.rendering.RenderState;
    import starling.textures.Texture;

    public class PointLightStyle extends MeshStyle implements IShadowMappedLight, IAreaLight
    {
        public function PointLightStyle()
        {
        }

        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var s:PointLightStyle = meshStyle as PointLightStyle

            _castsShadows = s.castsShadows;
            attenuation = s.attenuation;
            radius = s.radius;
            center = s.center;

            super.copyFrom(meshStyle);
        }

        override public function createEffect():MeshEffect
        {
            return new PointLightEffect();
        }

        public var center:Point = new Point();

        override public function updateEffect(effect:MeshEffect, state:RenderState):void
        {
            var e:PointLightEffect = effect as PointLightEffect;

            e.lightProps2[0] = _castsShadows ? 1.0 : 0.0;
            e.attenuation = attenuation;
            e.light = target;
            e.radius = radius;
            e.center = center;
            e.strength = 1.0; //todo: plug

           super.updateEffect(effect, state);
        }

        //
        //        private var targetMesh:Mesh;
        //
        //        override protected function onTargetAssigned(target:Mesh):void
        //        {
        //            if(target is MeshBatch) return;
        //            trace(target);
        //            targetMesh = target;
        //        }

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
        }

        ///////////////////////////////////////
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
            if(target is PointLight) (target as PointLight).setupVertices();
            //            createBuffers();
            //registerPrograms(); // todo: reregister shadow program
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
                // todo: make tex size param
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
    }
}
