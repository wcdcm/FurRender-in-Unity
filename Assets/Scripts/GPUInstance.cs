using UnityEngine;
 
[RequireComponent((typeof(MeshRenderer)))]
[ExecuteAlways]
public class GPUInstance : MonoBehaviour
{
    Mesh mesh; 
    Material material;
    [Header("壳层数")]public int shellCount = 100;
 
    private Matrix4x4[] matrices;
    //使用DrawInstanced()，为了正确合批，使用统一的MPB，一次绘制所有实例
    private MaterialPropertyBlock props;
    
    private ComputeBuffer shellIndexBuffer;
    
    float[] shellIndices;
    void Start()
    {
        material = GetComponent<MeshRenderer>().sharedMaterial;
        mesh = GetComponent<MeshFilter>().sharedMesh;
 
        if (!material.enableInstancing)
        {
            Debug.LogWarning("Fur material must enable GPU Instancing");
        }
 
        // 所有实例使用同一个 props，用数组传 ShellIndex
        matrices = new Matrix4x4[shellCount];
            
        props = new MaterialPropertyBlock();
        
        shellIndices = new float[shellCount];
        for (int i = 0; i < shellCount; i++)
        {
            matrices[i] = transform.localToWorldMatrix;
            shellIndices[i] = i;
        }
        
        shellIndexBuffer = new ComputeBuffer(shellCount, sizeof(float));
        shellIndexBuffer.SetData(shellIndices);
 
        material.SetBuffer("_ShellIndexBuffer", shellIndexBuffer);
    }
 
    void Update()
    {
        // 实例位置更新
        for (int i = 0; i < shellCount; i++)
        {
            matrices[i] = transform.localToWorldMatrix;
        }
 
        // 使用真正的 GPU Instancing 调用
        Graphics.DrawMeshInstanced(
            mesh,
            0,
            material,
            matrices,
            shellCount,
            props,
            UnityEngine.Rendering.ShadowCastingMode.Off,
            false
        );
    }
}