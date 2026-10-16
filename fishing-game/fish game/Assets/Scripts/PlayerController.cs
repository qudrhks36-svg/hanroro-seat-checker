using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(CharacterController))]
public class PlayerController : MonoBehaviour
{
    public Transform cameraTransform;
    public float moveSpeed = 4f;
    public float mouseSensitivity = 0.1f; // 도/픽셀
    public float gravity = -20f;

    CharacterController controller;
    float pitch;
    float verticalVelocity;

    void Awake()
    {
        controller = GetComponent<CharacterController>();
        Time.timeScale = 1f;   // 시작할 때는 항상 보통 속도 (프로젝트 설정이 0으로 저장돼 있어도 게임이 멈춘 채 시작하지 않게)
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        var kb = Keyboard.current;
        var mouse = Mouse.current;
        if (kb == null || mouse == null) return;
        if (CatalogUI.IsOpen || ShopNPC.IsOpen || TalkNPC.IsOpen || Time.frameCount == CatalogUI.ClosedFrame || Time.frameCount == ShopNPC.ClosedFrame || Time.frameCount == TalkNPC.ClosedFrame) return; // 도감이 열려 있는 동안은 입력을 도감이 처리

        if (kb.escapeKey.wasPressedThisFrame)
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
        else if (Cursor.lockState != CursorLockMode.Locked && mouse.leftButton.wasPressedThisFrame)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }
        if (Cursor.lockState != CursorLockMode.Locked) return;

        // 시점: 좌우는 몸, 상하는 카메라
        Vector2 look = mouse.delta.ReadValue() * mouseSensitivity;
        transform.Rotate(0f, look.x, 0f);
        pitch = Mathf.Clamp(pitch - look.y, -80f, 80f);
        cameraTransform.localRotation = Quaternion.Euler(pitch, 0f, 0f);

        // 이동: WASD
        float x = (kb.dKey.isPressed ? 1f : 0f) - (kb.aKey.isPressed ? 1f : 0f);
        float z = (kb.wKey.isPressed ? 1f : 0f) - (kb.sKey.isPressed ? 1f : 0f);
        Vector3 move = Vector3.ClampMagnitude(transform.right * x + transform.forward * z, 1f) * moveSpeed;

        verticalVelocity = controller.isGrounded ? -2f : verticalVelocity + gravity * Time.deltaTime;
        move.y = verticalVelocity;
        controller.Move(move * Time.deltaTime);
    }
}
