using UnityEngine;

public class CameraMover : MonoBehaviour
{
    public float moveSpeed = 0.25f;    // How fast the camera moves

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
    }

    // Update is called once per frame
    void Update()
    {
        var direction = Vector3.zero;

        if (Input.GetKey(KeyCode.W))
            direction += Vector3.up;
        if (Input.GetKey(KeyCode.S))
            direction += Vector3.down;
        if (Input.GetKey(KeyCode.A))
            direction += Vector3.left;
        if (Input.GetKey(KeyCode.D))
            direction += Vector3.right;
        if (Input.GetKey(KeyCode.Q))
            direction += Vector3.back;
        if (Input.GetKey(KeyCode.E))
            direction += Vector3.forward;

        transform.position += direction * Time.deltaTime * moveSpeed;
    }
}
