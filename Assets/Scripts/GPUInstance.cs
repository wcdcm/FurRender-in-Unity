using UnityEngine;

//[ExecuteAlways]
public class GPUInstance : MonoBehaviour
{
    public GameObject instanceGoal;
    private Mesh _mesh;
    private Material _material;

    public int instanceCount = 5;//GPU实例化的个数
    private Matrix4x4[] _matrices;//储存物体的TRS矩阵
    private MaterialPropertyBlock _propBlock;
    private float[] _thresholdArray;
    
    private void Awake()
    {
        _thresholdArray = new float[instanceCount];
        _propBlock =  new MaterialPropertyBlock();
        _mesh = instanceGoal.GetComponent<MeshFilter>().sharedMesh; 
        _material = instanceGoal.GetComponent<MeshRenderer>().sharedMaterial;
    }
    
    void Start()
    {
        _matrices = new Matrix4x4[instanceCount]; //初始化矩阵数组
		float scaleDelta = 1;	
        for (int i = 0; i < instanceCount; i++)
        { 
            Vector3 position = new Vector3(0, 0, 0);
            Quaternion rotation = Quaternion.identity;
            Vector3 scale = Vector3.one * scaleDelta;
            _matrices[i] = Matrix4x4.TRS(position, rotation, scale);
			scaleDelta += 0.01f;
            _thresholdArray[i] = i * 0.1f;
            if (_thresholdArray[i] > 1)
            {
                _thresholdArray[i] = 1;
            }
        }
    }

    void Update()
    {
        //一次性画一批，最多1023个
        // Graphics.DrawMeshInstanced(
        //     _mesh, 
        //     0, 
        //     _material, 
        //     _matrices, 
        //     _matrices.Length,
        //     _propBlock,
        //     UnityEngine.Rendering.ShadowCastingMode.On,
        //     true
        //     );
        for (int i = 0; i < instanceCount; i++)
        {
            _propBlock.SetFloat("threshold", _thresholdArray[i]);
            Graphics.DrawMesh(
                _mesh,
                _matrices[i],
                _material,
                0,
                null,
                0,
                _propBlock,
                true,
                true);
        }
    }
}
