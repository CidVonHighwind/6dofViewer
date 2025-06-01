using UnityEngine;

public class CameraWobbler : MonoBehaviour
{
    public float MovementX;
    public float MovementY;
    public float MovementZ;

    public float SpeedX = 1f;
    public float SpeedY = 1f;
    public float SpeedZ = 1f;

    public float RotationX;
    public float RotationY;
    public float RotationZ;

    public float RotationSpeedX = 1f;
    public float RotationSpeedY = 1f;
    public float RotationSpeedZ = 1f;

    private Vector3 startPosition;
    private Quaternion startRotation;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        startPosition = transform.position;
        startRotation = transform.rotation;
    }

    // Update is called once per frame
    void Update()
    {
        // Position Oscillation
        float x = Mathf.Sin(Time.time * SpeedX) * MovementX;
        float y = Mathf.Sin(Time.time * SpeedY) * MovementY;
        float z = Mathf.Sin(Time.time * SpeedZ) * MovementZ;

        transform.position = startPosition + new Vector3(x, y, z);

        // Rotation Oscillation
        float rotX = Mathf.Sin(Time.time * RotationSpeedX) * RotationX;
        float rotY = Mathf.Sin(Time.time * RotationSpeedY) * RotationY;
        float rotZ = Mathf.Sin(Time.time * RotationSpeedZ) * RotationZ;

        transform.rotation = startRotation * Quaternion.Euler(rotX, rotY, rotZ);
    }
}
