package starling.extensions.deferredShading.debug
{
    import flash.display3D.Context3D;
    import flash.display3D.Context3DProgramType;

    import starling.extensions.utils.ShaderUtils;
    import starling.rendering.MeshEffect;
    import starling.rendering.Program;
    import starling.rendering.VertexDataFormat;

    public class DebugImageEffect extends MeshEffect
    {
        public static const VERTEX_FORMAT:VertexDataFormat = VertexDataFormat.fromString("position:float2, texCoords:float2, color:bytes4");

        // Shader constants


        public function DebugImageEffect()
        {
        }

        override protected function createProgram():Program
        {
            var vertexProgramCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                'm44 op, va0, vc0', // 4x4 matrix transform to output space
                                'mov vt1, va2', // just reference va2, otherwise context throws an error about not using it in the shader
                                'mov v0, va1'
                            ]
                    );

            var fragmentProgramCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                'tex ft0, v0, fs0 <2d, clamp, linear, mipnone>',
                                'mov ft0.w, fc0.w',
                                'mov oc, ft0'
                            ]
                    );

            var fragmentProgramCodeChannelR:String =
                    ShaderUtils.joinProgramArray(
                            [
                                'tex ft0, v0, fs0 <2d, clamp, linear, mipnone>',
                                'mov ft0.yz, ft0.xx',
                                'mov ft0.w, fc0.w',
                                'mov oc, ft0'
                            ]
                    );

            var fragmentProgramCodeChannelA:String =
                    ShaderUtils.joinProgramArray(
                            [
                                'tex ft0, v0, fs0 <2d, clamp, linear, mipnone>',
                                'mov ft0.xyz, ft0.www',
                                'mov ft0.w, fc0.w',
                                'mov oc, ft0'
                            ]
                    );

            if(_showChannel == -1) return Program.fromSource(vertexProgramCode, fragmentProgramCode);
            else if(_showChannel == 0) return Program.fromSource(vertexProgramCode, fragmentProgramCodeChannelR);
            else return Program.fromSource(vertexProgramCode, fragmentProgramCodeChannelA);
        }

        override protected function get programVariantName():uint
        {
            var bits:uint = 0;

            if(_showChannel == 0)
                bits = 1;
            else if(_showChannel == 3)
                bits = 2;

            return bits;
        }

        override protected function beforeDraw(context:Context3D):void
        {
            super.beforeDraw(context);
            // todo: cleanup
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, new <Number>[1,1,1,1]);
        }

        override protected function afterDraw(context:Context3D):void
        {


            super.afterDraw(context);
        }

        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }

        public var _showChannel:int;
    }
}
