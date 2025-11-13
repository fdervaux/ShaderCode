using UnityEngine;

public class RotateObject : MonoBehaviour
{
    [SerializeField] private Vector3 _rotationSpeed = new Vector3(20, 100, 55);
    
    void Update()
    {
        transform.Rotate(_rotationSpeed * Time.deltaTime);    
    }
}
