using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

namespace ShaderCode._8_Outline
{
    public class OutlineRendererFeature : ScriptableRendererFeature
    {
        private static readonly int OutlineColor = Shader.PropertyToID("_OutlineColor");
        private static readonly int OutlineDepthThreshold = Shader.PropertyToID("_OutlineDepthThreshold");
        private static readonly int OutlineNormalThreshold = Shader.PropertyToID("_OutlineNormalThreshold");
        private static readonly int OutlineKernelSize = Shader.PropertyToID("_OutlineKernelSize");
        private static readonly int OutlineWidth = Shader.PropertyToID("_OutlineWidth");
        private static readonly int OutlineEllipseWidth = Shader.PropertyToID("_OutlineEllipseWidth");
        private static readonly int OutlineEllipseAngle = Shader.PropertyToID("_OutlineEllipseAngle");
        private static readonly int SecondOutlineColor = Shader.PropertyToID("_SecondOutlineColor");


        [Tooltip("The material used when making the blit operation.")]
        public Material _material;

        [Tooltip("The event where to inject the pass.")]
        public RenderPassEvent _renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        
        [Tooltip("Specifies what inputs are required by this render pass.")]
        public ScriptableRenderPassInput _requirements = ScriptableRenderPassInput.None;
        
        // Exposed parameters
        [Tooltip("Outline color.")]
        public Color _outlineColor = Color.black;
        
        // Exposed parameters
        [Tooltip("Second Outline color.")]
        public Color _secondOutlineColor = Color.black;
        
        [Tooltip("Depth threshold for outline detection.")]
        [Range(0f, 1f)]
        public float _outlineDepthThreshold = 0.01f;
        
        [Tooltip("Normal threshold for outline detection.")]
        [Range(0f, 1f)]
        public float _outlineNormalThreshold = 0.2f;
        
        [Tooltip("Kernel size for the outline (3..7).")]
        [Range(3, 11)]
        public int _outlineKernelSize = 3;

        [Range(1,10)]
        [Tooltip("Outline width in pixels.")]
        public float _outlineWidth = 1;
        
        [Tooltip("Ellipse width (relative, 1 = rayon égal à half_kernel_size).")]
        [Range(0f, 1f)]
        public float _outlineEllipseWidth = 1.0f;

        [Tooltip("Ellipse angle in radians.")]
        [Range(0f, 6.283185f)]
        public float _outlineEllipseAngle;

        private OutlineRendererPass _pass;
        private Material _materialInstance;
        
        public override void Create()
        {
            _pass = new OutlineRendererPass
            {
                renderPassEvent = _renderPassEvent
            };
        }
        
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!_material)
            {
                Debug.LogWarning(this.name + " material is null and will be skipped.");
                return;
            }
            
            // ensure we have an instance to modify without touching the asset
            if (!_materialInstance || _materialInstance.shader != _material.shader)
            {
                if (_materialInstance)
                    DestroyImmediate(_materialInstance);

                _materialInstance = new Material(_material)
                {
                    name = _material.name + " (Instance)"
                };
            }

            // assign properties to the material instance
            _materialInstance.SetColor(OutlineColor, _outlineColor);
            _materialInstance.SetColor(SecondOutlineColor, _secondOutlineColor);
            _materialInstance.SetFloat(OutlineDepthThreshold, _outlineDepthThreshold);
            _materialInstance.SetFloat(OutlineNormalThreshold, _outlineNormalThreshold);
            _materialInstance.SetInt(OutlineKernelSize, _outlineKernelSize);
            _materialInstance.SetFloat(OutlineWidth, _outlineWidth);
            _materialInstance.SetFloat(OutlineEllipseWidth, _outlineEllipseWidth);
            _materialInstance.SetFloat(OutlineEllipseAngle, _outlineEllipseAngle);
        
            _pass.ConfigureInput(_requirements);
            _pass.Setup(_materialInstance);
            renderer.EnqueuePass(_pass);        
        }
    }
}


