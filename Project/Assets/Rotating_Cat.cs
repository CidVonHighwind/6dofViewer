using UnityEngine;

public class Rotating_Cat : MonoBehaviour
{
    public GameObject rotatingCat;      // The cat model that rotates
    public GameObject idleCat;          // The cat model shown after rotation

    public float rotationSpeed = 90f;   // Degrees per second
    public float rotationDuration = 2f; // Time to rotate before switching (seconds)
    public float rotationMultiplier = 1.0f;

    public float bobbingAmplitude = 0.05f;  // height of sine wave
    public float bobbingFrequency = 3f;     // speed of sine wave

    private float timer = 1f;
    private bool rotationFinished = true;
    private Vector3 originalPosition;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        // Save starting Y position
        originalPosition = transform.position;

        // Set initial visibility
        rotatingCat.SetActive(false);
        idleCat.SetActive(true);
    }

    // Update is called once per frame
    void Update()
    {
        if (!rotationFinished)
        {
            timer += Time.deltaTime;

            // Rotation
            transform.Rotate(Vector3.up, -rotationSpeed * rotationMultiplier * Time.deltaTime);

            // Bobbing (sinusoidal up/down motion)
            float newY = originalPosition.y + Mathf.Sin(Time.time * bobbingFrequency) * bobbingAmplitude;
            transform.position = new Vector3(originalPosition.x, newY, originalPosition.z);

            // Check if rotation time is up
            if (timer >= rotationDuration)
            {
                timer = 0.1f + Random.value * 0.5f;
                rotationFinished = true;
                rotatingCat.SetActive(false);
                idleCat.SetActive(true);

                transform.rotation = Quaternion.identity;
            }
        }
        else
        {
            timer -= Time.deltaTime;

            if (timer < 0)
            {
                rotationMultiplier = 0.75f + Random.value;
                rotationFinished = false;
                rotatingCat.SetActive(true);
                idleCat.SetActive(false);
            }
        }
    }
}
