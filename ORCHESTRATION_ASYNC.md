# OpenClaw 심층 오케스트레이션 검증 - 비동기 처리

## 목표
- `setTimeout`, `Promise`, `async/await` 등 비동기 로직이 포함된 코드가 OpenClaw 환경에서 정상적으로 실행되고 출력되는지 확인.
- 장시간 실행되는 프로세스가 중단되지 않는지 확인.

## 코드
```javascript
const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function runAsyncTasks() {
    console.log('Task 1: Starting...');
    await wait(500);
    console.log('Task 1: Done.');

    console.log('Task 2: Starting...');
    await wait(500);
    console.log('Task 2: Done.');

    console.log('All Tasks Completed.');
}

runAsyncTasks();
```

## 예상 결과
순차적으로 로그가 출력되어야 함 (총 약 1초 소요).
